# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterYAML < Pharos::Phase
      title "Store cluster YAML"
      runs_on :master_host

      def call
        logger.info { "Storing cluster configuration to configmap" }
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
            'cluster.yml' => @config.content,
            'pharos-version' => Pharos::VERSION
          }
        )
      end
    end
  end
end
