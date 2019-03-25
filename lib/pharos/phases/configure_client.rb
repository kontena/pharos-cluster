# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig_file.exist?

        cluster_context['kubeconfig'] = kubeconfig

        client_prefetch
      end

      # @return [Pharos::Transport::TransportFile]
      def kubeconfig_file
        @kubeconfig_file ||= transport.file(REMOTE_FILE)
      end

      # @return [K8s::Config]
      def kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = YAML.safe_load(kubeconfig_file.read)

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
