# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        return if cluster_context['kube_client']
        return unless kubeconfig?

        mutex.synchronize do
          if host.local?
            cluster_context['kube_client'] ||= Pharos::Kube.client('localhost', k8s_config, 6443)
          else
            cluster_context['kube_client'] ||= Pharos::Kube.client('localhost', k8s_config, transport.forward(host.api_address, 6443))
          end
        end

        client_prefetch
      end

      def kubeconfig
        @kubeconfig ||= transport.file(REMOTE_FILE)
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
        kube_client.apis(prefetch_resources: true)
      end
    end
  end
end
