# frozen_string_literal: true

module Pharos
  module Phases
    class FetchClusterConfiguration < Pharos::Phase
      title "Fetch cluster configuration"

      def call
        logger.info { "Fetching cluster configuration from configmap ..." }

        config_map = previous_config_map
        return unless config_map

        cluster_context['previous-config-map'] = config_map
        cluster_context['previous-config'] = build_config(config_map)
      end

      # @param configmap [Kubeclient::Resource]
      # @return [Pharos::Config]
      def build_config(configmap)
        cluster_config = Pharos::YamlFile.new(StringIO.new(configmap.data['cluster.yml']), override_filename: "#{@host}:cluster.yml").load
        cluster_config['hosts'] ||= []
        data = Pharos::ConfigSchema.build.call(cluster_config)
        Pharos::Config.new(data)
      end

      # @return [Kubeclient::Resource]
      def previous_config_map
        @kube.client('v1').get_config_map('pharos-config', 'kube-system')
      rescue Kubeclient::ResourceNotFoundError
        nil
      end
    end
  end
end
