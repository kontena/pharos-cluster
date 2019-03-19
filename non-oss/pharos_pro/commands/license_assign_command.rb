# frozen_string_literal: true

module Pharos
  class LicenseAssignCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    options :load_config, :tf_json

    parameter "[LICENSE_KEY]", "kontena pharos license key (default: <stdin>)"
    option '--description', 'DESCRIPTION', "license description [DEPRECATED]", hidden: true
    option %w(-f --force), :flag, "force assign invalid/expired token"

    def execute
      warn '[DEPRECATED] the --description option is deprecated and will be ignored' if description
      cluster_manager('force' => force?, 'no-generate-name' => true)
      puts decorate_license

      unless jwt_token.valid? || force?
        signal_error "License is not valid"
      end

      Dir.chdir(config_yaml.dirname) do
        master_host.transport.connect
        master_host.transport.exec!("kubectl create secret generic pharos-license --namespace=kube-system --from-literal='license.jwt=#{jwt_token.token}' --dry-run -o yaml | kubectl apply -f -")
        logger.info "Assigned the subscription token successfully to the cluster.".green
      end
    end

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
                       Pharos::LicenseKey.new(license_key, cluster_id: cluster_id)
                     end
    end

    def master_host
      @master_host ||= load_config.master_host
    end

    def cluster_id
      cluster_manager.context['cluster-id'] || signal_error('Failed to get cluster id')
    end

    def cluster_name
      load_config.name || signal_error('Failed to get cluster name')
    end

    def subscription_token_request
      logger.info "Exchanging license key for a subscription token" if $stdout.tty?

      Excon.post(
        'https://get.pharos.sh/api/licenses/%<key>s/assign' % { key: license_key },
        body: JSON.dump(
          data: {
            attributes: {
              'cluster-id' => cluster_id,
              'description' => cluster_name
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
