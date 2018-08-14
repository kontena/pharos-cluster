# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterConfiguration < Pharos::Phase
      title "Store cluster configuration"

      def call
        logger.info { "Storing cluster configuration to configmap ..." }
        ensure_resource(resource)
      end

      private

      def resource
        data = JSON.parse(@config.data.to_json) # hack to get rid of symbols
        K8s::Resource.new(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'pharos-config'
          },
          data: {
            'cluster.yml' => data.to_yaml,
            'pharos-version' => Pharos::VERSION,
            'pharos-components.yml' => components.to_yaml,
            'pharos-addons.yml' => addons.to_yaml
          }
        )
      end

      def ensure_resource(resource)
        kube_client.update_resource(resource)
      rescue K8s::Error::NotFound
        kube_client.create_resource(resource)
      end

      def components
        JSON.parse(Pharos::Phases.components_for_config(@config).sort_by(&:name).map(&:to_h).to_json)
      end

      def addons
        JSON.parse(Pharos::AddonManager.addons.map(&:to_h).select { |a| @config.addons.dig(a[:name], 'enabled') }.to_json)
      end
    end
  end
end
