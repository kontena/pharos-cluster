# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig?

        cluster_context['kubeconfig'] = kubeconfig
      end

      # @return [String]
      def kubeconfig?
        @ssh.file(REMOTE_FILE).exist?
      end

      # @return [K8s::Config]
      def read_kubeconfig
        @ssh.file(REMOTE_FILE).read
      end

      # @return [K8s::Config]
      def kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = YAML.safe_load(read_kubeconfig)

        logger.debug { "New config: #{config}" }
        K8s::Config.new(config)
      end
    end
  end
end
