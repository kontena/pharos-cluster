# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterYAML < Pharos::Phase
      PHASE_TITLE = "Store cluster YAML"

      # @param config_content [String]
      def initialize(host, config_content: , **options)
        super(host, **options)
        @config_content = config_content
      end

      def call
        logger.info { "Storing cluster configuration to configmap" }
        configmap = resource
        begin
          Pharos::Kube.update_resource(@master.address, configmap)
        rescue Kubeclient::ResourceNotFoundError
          Pharos::Kube.create_resource(@master.address, configmap)
        end
      end

      private

      def resource
        Kubeclient::Resource.new(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'pharos-config'
          },
          data: {
            'cluster.yml' => @config_content
          }
        )
      end
    end
  end
end
