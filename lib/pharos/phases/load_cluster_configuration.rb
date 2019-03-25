# frozen_string_literal: true

module Pharos
  module Phases
    class LoadClusterConfiguration < Pharos::Phase
      title "Load cluster configuration"

      def call
        logger.info { "Loading cluster configuration configmap ..." }

        pharos_config_map = pharos_config_configmap
        return unless pharos_config_map

        cluster_context['previous-config-map'] = pharos_config_map
        cluster_context['previous-config'] = build_config(pharos_config_map)

        logger.info { "Loading cluster-info configmap ..." }
        info_config = cluster_info_configmap

        cluster_context['cluster-id'] = info_config&.metadata&.uid
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
        with_ssl_retry do
          kube_client.api('v1').resource('configmaps', namespace: 'kube-system').get('pharos-config')
        end
      rescue K8s::Error::NotFound
        logger.error { "pharos-config configmap was not found" }
        nil
      end

      def cluster_info_configmap
        with_ssl_retry do
          kube_client.api('v1').resource('configmaps', namespace: 'kube-public').get('cluster-info')
        end
      rescue K8s::Error::NotFound
        logger.error { "cluster-info configmap was not found" }
        nil
      end

      private

      def with_ssl_retry
        original_ssl_verify_peer = kube_client.transport.options[:ssl_verify_peer]
        begin
          yield
        rescue Excon::Error::Socket => ex
          raise if kube_client.transport.options[:ssl_verify_peer] == false # don't re-retry

          kube_client.transport.options[:ssl_verify_peer] = false
          logger.warn { "Encountered #{ex.class.name} : #{ex.message} - retrying with ssl verify peer disabled" }
          retry
        ensure
          kube_client.transport.options[:ssl_verify_peer] = original_ssl_verify_peer
        end
      end
    end
  end
end
