# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureServiceAccount < Pharos::Phase
      title "Configure 'pharos-admin' service account"

      ADMIN_USER = 'pharos-admin'
      KUBECONFIG_PARAM = '--kubeconfig=/etc/kubernetes/admin.conf'

      def call
        logger.info "Creating service account"
        create_service_account
        logger.info "Creating cluster role binding"
        create_cluster_role_binding

        config = build_config

        if config_file.exist?
          logger.info "Merging existing configuration"
          existing_config = Pharos::Kube::Config.new(config_file.read)
          config << existing_config
        end

        logger.info "Writing configuration file to #{config_file.path}"
        config_file.write(config.dump, overwrite: true)
        config_file.chmod('0600')

        logger.info "Validating that new configuration works"
        validate
      end

      def validate
        # Validates that "kubectl" without sudo or setting KUBECONFIG / --kubeconfig works on the host
        transport.exec!("kubectl get --kubeconfig=~/.kube/config -n kube-system serviceaccount/#{ADMIN_USER}")
      end

      def config_file
        @config_file ||= transport.file(File.join(home_kube_dir.path, 'config'))
      end

      # Get a real path to ~/.kube and mkdir + chmod it unless exists
      def home_kube_dir
        transport.file('~/.kube', expand: true).tap do |dir|
          transport.exec!("mkdir '#{dir}' && chmod 0700 '#{dir}") unless dir.exist?
        end
      end

      # Sudo used because /etc/kubernetes/admin.conf is not user-readable
      def create_service_account
        transport.exec!("sudo kubectl get #{KUBECONFIG_PARAM} -n kube-system serviceaccount/#{ADMIN_USER} || sudo kubectl #{KUBECONFIG_PARAM} -n kube-system create serviceaccount #{ADMIN_USER}")
      end

      def create_cluster_role_binding
        transport.exec!("sudo kubectl get #{KUBECONFIG_PARAM} -n kube-system clusterrolebinding/pharos-cluster-admin || sudo kubectl create #{KUBECONFIG_PARAM} -n kube-system clusterrolebinding pharos-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:#{ADMIN_USER}")
      end

      # @return token_name [String]
      def token_name
        transport.exec!("sudo kubectl -n kube-system #{KUBECONFIG_PARAM} get serviceaccount/#{ADMIN_USER} -o jsonpath='{.secrets[0].name}'")
      end

      # @return token [String]
      def token
        @token ||= transport.exec!("sudo kubectl -n kube-system #{KUBECONFIG_PARAM} get secret #{token_name} -o jsonpath='{.data.token}' | base64 -d")
      end

      # @return [Pharos::Kube::Config]
      def build_config
        config = Pharos::Kube::Config.new
        config.config['clusters'] << {
          'cluster' => {
            'certificate-authority-data' => certificate_authority_data,
            'server' => "https://#{master_host.api_address}:6443"
          },
          'name' => @config.name
        }

        config.config['users'] << {
          'user' => {
            'token' => token
          },
          'name' => ADMIN_USER
        }

        config.config['contexts'] << {
          'context' => {
            'cluster' => @config.name,
            'user' => ADMIN_USER
          },
          'name' => context_name
        }

        config.config['current-context'] = context_name

        config
      end

      # @return [String]
      def context_name
        @context_name ||= "#{ADMIN_USER}@#{@config.name}"
      end

      # @return [String]
      def certificate_authority_data
        # --flatten expands relative paths, --minify cleans out everything but the stuff needed by current_context
        transport.exec!("sudo kubectl config view #{KUBECONFIG_PARAM} --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}'")
      end
    end
  end
end
