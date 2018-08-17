# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        fetch_kubeconfig
        client_prefetch
      end

      def fetch_kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = Pharos::Kube::Config.new(@ssh.file(REMOTE_FILE).read)
        config.update_server_address(@host.api_address)
        logger.debug "New config: #{config}"
        cluster_context['kubeconfig'] = config.to_h
      end

      # prefetch client resources to warm up caches
      def client_prefetch
        kube_client.apis(prefetch_resources: true)
      end
    end
  end
end
