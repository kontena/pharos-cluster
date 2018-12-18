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
        cluster_context['master-ssh'] = ssh

        client_prefetch unless @optional
      end

      # @return [String]
      def kubeconfig?
        ssh.file(REMOTE_FILE).exist?
      end

      # @return [K8s::Config]
      def read_kubeconfig
        ssh.file(REMOTE_FILE).read
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
