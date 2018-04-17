# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterYAML < Pharos::Phase
      title "Store cluster YAML"

      # @param config_content [String]
      def initialize(host, config_content:, **options)
        super(host, **options)
        @config_content = config_content
      end

      def call
        info "Storing cluster configuration to configmap"
        resource.apply
      end

      private

      def resource
        Pharos::Kube.session(@master).resource(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'pharos-config'
          },
          data: {
            'cluster.yml' => @config_content,
            'pharos-version' => Pharos::VERSION
          }
        )
      end
    end
  end
end
