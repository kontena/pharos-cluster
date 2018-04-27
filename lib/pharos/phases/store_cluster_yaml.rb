# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterYAML < Pharos::Phase
      title "Store cluster YAML"

      def call
        info "Storing cluster configuration to configmap ..."
        resource.apply
      end

      private

      def resource
        data = JSON.parse(@config.data.to_json) # hack to get rid of symbols
        Pharos::Kube.session(@master).resource(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'pharos-config'
          },
          data: {
            'cluster.yml' => data.to_yaml,
            'pharos-version' => Pharos::VERSION
          }
        )
      end
    end
  end
end
