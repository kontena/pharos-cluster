# frozen_string_literal: true

module Pharos
  module CommandOptions
    module LicenseKey
      def self.included(base)
        base.prepend(InstanceMethods)
        base.parameter "[LICENSE_KEY]", "kontena pharos license key (default: <stdin>)"
        base.options :load_config unless base.instance_methods.include?(:load_config)
      end

      module InstanceMethods
        private

        def default_license_key
          if tty?
            prompt.ask('Enter Kontena Pharos license key:')
          elsif !stdin_eof?
            $stdin.read
          else
            signal_usage_error 'LICENSE_KEY required'
          end
        end

        def jwt_token
          @jwt_token ||= if license_key.match?(/^\h{8}-(?:\h{4}-){3}\h{12}$/)
                           Pharos::LicenseKey.new(subscription_token, cluster_id: cluster_id)
                         else
                           begin
                             load_config
                             c_id = cluster_id
                           rescue StandardError
                             c_id = nil
                           end
                           Pharos::LicenseKey.new(license_key, cluster_id: c_id)
                         end
        end

        def master_host
          @master_host ||= load_config.master_host
        end

        def cluster_info
          @cluster_info ||= Pharos::YamlFile.new(
            StringIO.new(cluster_info_configmap),
            override_filename: "#{master_host.address}:kube-public/cluster-info"
          ).load
        end

        def cluster_info_configmap
          Dir.chdir(config_yaml.dirname) do
            master_host.transport.connect
            master_host.transport.exec!('kubectl get configmap --namespace kube-public -o yaml cluster-info')
          end
        rescue Pharos::ExecError => ex
          signal_error "Failed to get cluster-info configmap: #{ex.message}"
        end

        def cluster_id
          cluster_info.dig('metadata', 'uid')
        end

        def cluster_name
          Pharos::YamlFile.new(
            StringIO.new(cluster_info.dig('data', 'kubeconfig')),
            override_filename: "#{master_host.address}:kube-public/cluster-info.data.kubeconfig"
          ).load.dig('clusters', 0, 'name')
        rescue StandardError => ex
          signal_error "Failed to parse cluster name from cluster-info.kubeconfig: #{ex.class.name} : #{ex.message}"
        end

        def subscription_token_request
          logger.info "Exchanging license key for a subscription token" if $stdout.tty?

          Excon.post(
            'https://get.pharos.sh/api/licenses/%<key>s/assign' % { key: license_key },
            body: JSON.dump(
              data: {
                attributes: {
                  cluster_id: cluster_id,
                  description: cluster_name
                }
              }
            ),
            headers: {
              'Accept' => 'application/json',
              'Content-Type' => 'application/json',
              'User-Agent' => "pharos-cluster/#{Pharos.version}"
            }
          )
        end

        def subscription_token
          response = JSON.parse(subscription_token_request.body)
          signal_error response['errors'].map { |error| error['title'] }.join(', ') if response['errors']
          response.dig('data', 'attributes', 'license-token', 'jwt') || signal_error('invalid response')
        end

        def decorate_license
          lexer = Rouge::Lexers::YAML.new
          if color?
            rouge.format(lexer.lex(jwt_token.to_h.to_yaml.delete_prefix("---\n")))
          else
            jwt_token.to_h.to_yaml.delete_prefix("---\n")
          end
        end
      end
    end
  end
end
