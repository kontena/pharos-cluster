# frozen_string_literal: true

module Pharos
  module Phases
    class StoreClusterConfiguration < Pharos::Phase
      using Pharos::CoreExt::DeepTransformKeys

      on :master_host

      title "Store cluster configuration"

      def call
        logger.info { "Storing cluster configuration to configmap ..." }
        ensure_resource(resource)
      end

      private

      def resource
        data = @config.data.to_h.deep_transform_keys(&:to_s)
        K8s::Resource.new(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'kube-system',
            name: 'pharos-config'
          },
          data: {
            'cluster.yml' => data.to_yaml,
            'pharos-version' => Pharos.version,
            'pharos-components.yml' => components.to_yaml,
            'pharos-cluster-name' => @config.name,
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
        Pharos::Phases.components_for_config(@config).sort_by(&:name).map { |c| c.to_h.deep_stringify_keys }
      end

      def addons
        Pharos::AddonManager.addon_classes.map(&:to_h).select { |a| @config.addons.dig(a[:name], 'enabled') }.map(&:deep_stringify_keys)
      end
    end
  end
end
