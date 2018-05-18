# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterConfiguration < Pharos::Phase
      title "Store cluster configuration"

      def initialize(*args, addon_manager: , **options)
        super(*args, **options)

        @addon_manager = addon_manager
      end

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
            'pharos-components.yml' => components.to_yaml,
            'pharos-addons.yml' => addons.to_yaml
          }
        )
      end

      def components
        JSON.parse(Pharos::Phases.components_for_config(@config).sort_by(&:name).map(&:to_h).to_json)
      end

      def addons
        addons = []
        
        @addon_manager.with_enabled_addons do |addon_class, addon_config|
          addons << addon_class.to_h
        end

        JSON.parse(addons.to_json)
      end
    end
  end
end
