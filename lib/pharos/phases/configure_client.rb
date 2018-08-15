# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        fetch_kubeconfig
        client_prefetch
        config_map = previous_config_map
        return unless config_map

        cluster_context['previous-config-map'] = config_map
        cluster_context['previous-config'] = build_config(config_map)
      end

      def fetch_kubeconfig
        logger.info { "Fetching kubectl config ..." }
        config = Pharos::Kube::Config.new(@ssh.file(REMOTE_FILE).read)
        config.update_server_address(@host.api_address)
        logger.debug "New config: #{config}"
        cluster_context['kubeconfig'] = config.to_h
      end

      # prefetch client resources to warm up caches
      def client_prefetch
        kube_client.apis(prefetch_resources: true)
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
