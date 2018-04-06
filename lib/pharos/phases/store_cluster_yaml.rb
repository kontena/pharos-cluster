# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class StoreClusterYAML < Base
      # @param master [Pharos::Configuration::Node]
      # @param config [Pharos::Config]
      def initialize(master, config_content)
        @master = master
        @config_content = config_content
      end

      def call
        logger.info(@master.address) { "Storing cluster configuration to configmap" }
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
