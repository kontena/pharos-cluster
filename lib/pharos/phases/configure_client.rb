# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        cluster_context['kubeconfig'] = fetch_kubeconfig

        client_prefetch
      end

      # @return [String]
      def read_kubeconfig
        @ssh.file(REMOTE_FILE).read
      end

      # @return [Hash]
      def fetch_kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = Pharos::Kube::Config.new(read_kubeconfig)
        config.update_server_address(@host.api_address)

        logger.debug { "New config: #{config}" }
        config.to_h
      end

      # prefetch client resources to warm up caches
      def client_prefetch
        kube_client.apis(prefetch_resources: true)
      end
    end
  end
end
