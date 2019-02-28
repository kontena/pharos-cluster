# frozen_string_literal: true

module Pharos
  module Phases
    class LoadClusterConfiguration < Pharos::Phase
      title "Load cluster configuration"

      def call
        config_map = previous_config_map
        return unless config_map

        logger.info { "Loading previous cluster configuration from configmap ..." }

        cluster_context['previous-config-map'] = config_map
        cluster_context['previous-config'] = build_config(config_map)
      end

      # @param configmap [K8s::Resource]
      # @return [Pharos::Config]
      def build_config(configmap)
        cluster_config = Pharos::YamlFile.new(StringIO.new(configmap.data['cluster.yml']), override_filename: "#{@host}:cluster.yml").load
        cluster_config['hosts'] ||= []
        data = Pharos::ConfigSchema.build.call(cluster_config)
        Pharos::Config.new(data)
      end

      # @return [K8s::Resource, nil]
      def previous_config_map
        kube_client.api('v1').resource('configmaps', namespace: 'kube-system').get('pharos-config')
      rescue K8s::Error::NotFound
        nil
      end
    end
  end
end
