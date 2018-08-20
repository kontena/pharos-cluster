# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      # @param optional [Boolean] skip if kubeconfig does not exist instead of failing
      def initialize(host, optional: false, **options)
        super(host, **options)

        @optional = optional
      end

      def call
        return if @optional && !kubeconfig?

        cluster_context['kubeconfig'] = kubeconfig

        client_prefetch unless @optional
      end

      # @return [String]
      def kubeconfig?
        @ssh.file(REMOTE_FILE).exist?
      end

      # @return [String]
      def read_kubeconfig
        @ssh.file(REMOTE_FILE).read
      end

      # @return [Hash]
      def kubeconfig
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
