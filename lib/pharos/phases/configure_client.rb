# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      on :master_host

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig?

        cluster_context['kubeconfig'] = kubeconfig

        client_prefetch
      end

      # @return [String]
      def kubeconfig?
        transport.file(REMOTE_FILE).exist?
      end

      # @return [K8s::Config]
      def read_kubeconfig
        transport.file(REMOTE_FILE).read
      end

      # @return [K8s::Config]
      def kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = YAML.safe_load(read_kubeconfig)

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
