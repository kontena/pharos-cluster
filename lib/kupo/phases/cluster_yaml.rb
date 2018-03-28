# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ClusterYAML < Base
      # @param master [Kupo::Configuration::Node]
      # @param config [Kupo::Config]
      def initialize(master, config)
        @master = master
        @config = config
      end

      def call
        logger.info(@master.address) { "Storing cluster configuration to configmap" }
        configmap = resource
        begin
          Kupo::Kube.update_resource(@master.address, configmap)
        rescue Kubeclient::ResourceNotFoundError
          Kupo::Kube.create_resource(@master.address, configmap)
        end
      end

      private

      def resource
        Kubeclient::Resource.new(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'cluster-yaml'
          },
          data: {
            'cluster.yml' => @config
          }
        )
      end
    end
  end
end

