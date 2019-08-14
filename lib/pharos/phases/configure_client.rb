# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig?

        if host.local?
          cluster_context['kube_client'] = Pharos::Kube.client('localhost', k8s_config, 6443)
        else
          transport.close(cluster_context['kube_client'].transport.server[/:(\d+)/, 1].to_i) if cluster_context['kube_client']
          cluster_context['kube_client'] = Pharos::Kube.client('localhost', k8s_config, transport.forward('localhost', 6443))
        end

        client_prefetch
      end

      def kubeconfig
        @kubeconfig ||= user_config.exist? ? user_config : transport.file(REMOTE_FILE)
      end

      def user_config
        @user_config ||= transport.file('~/.kube/config', expand: true)
      end

      # @return [String]
      def kubeconfig?
        kubeconfig.exist?
      end

      # @return [K8s::Config]
      def k8s_config
        logger.info { "Fetching kubectl config ..." }
        config = YAML.safe_load(kubeconfig.read)

        logger.debug { "New config: #{config}" }
        K8s::Config.new(config)
      end

      # prefetch client resources to warm up caches
      def client_prefetch
        logger.info "Populating client cache"
        kube_client.apis(prefetch_resources: true)
      rescue Excon::Error::Certificate
        logger.warn "Certificate validation failed"
      end
    end
  end
end
