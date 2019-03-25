# frozen_string_literal: true

module Pharos
  module Phases
    class LoadClusterConfiguration < Pharos::Phase
      title "Load cluster configuration"

      def call
        logger.info { "Loading cluster configuration configmap ..." }

        pharos_config_map = pharos_config_configmap
        return unless pharos_config_map

        cluster_context.previous_configmap = pharos_config_map
        cluster_context.previous_config = build_config(pharos_config_map)

        logger.info { "Loading cluster-info configmap ..." }
        info_config = cluster_info_configmap

        cluster_context.cluster_id = info_config&.metadata&.uid
        cluster_context['cluster-created-at'] = info_config&.metadata&.creationTimestamp
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
      def pharos_config_configmap
        kube_client.api('v1').resource('configmaps', namespace: 'kube-system').get('pharos-config')
      rescue K8s::Error::NotFound
        logger.error { "pharos-config configmap was not found" }
        nil
      end

      def cluster_info_configmap
        kube_client.api('v1').resource('configmaps', namespace: 'kube-public').get('cluster-info')
      rescue K8s::Error::NotFound
        logger.error { "cluster-info configmap was not found" }
        nil
      end
    end
  end
end
