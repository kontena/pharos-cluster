# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterConfiguration < Pharos::Phase
      title "Store cluster configuration"

      def call
        logger.info { "Storing cluster configuration to configmap ..." }
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
            'pharos-version' => Pharos::VERSION,
            'pharos-components' => components.to_yaml,
            'pharos-addons' => addons.to_yaml
          }
        )
      end

      def components
        JSON.parse(Pharos::Phases.components_for_config(@config).sort_by(&:name).map(&:to_h).to_json)
      end

      def addons
        JSON.parse(Pharos::Addon.descendants.map(&:to_h).select { |a| @config.addons.dig(a[:name], 'enabled') }.to_json)
      end
    end
  end
end
