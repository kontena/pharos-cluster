# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        save_config_locally
        client_prefetch
        config_map = previous_config_map
        return unless config_map

        cluster_context['previous-config-map'] = config_map
        cluster_context['previous-config'] = build_config(config_map)
      end

      def save_config_locally
        Dir.mkdir(config_dir, 0o700) unless Dir.exist?(config_dir)

        logger.info { "Fetching kubectl config ..." }
        config_data = remote_config_file.read
        File.chmod(0o600, config_file) if File.exist?(config_file)
        File.write(config_file, config_data.gsub(%r{(server: https://)(.+)(:6443)}, "\\1#{@host.api_address}\\3"), perm: 0o600)
        logger.info { "Configuration saved to #{config_file}" }
      end

      def remote_config_file
        @ssh.file(REMOTE_FILE)
      end

      def config_file
        File.join(config_dir, @host.api_address)
      end

      def config_dir
        File.join(Dir.home, '.pharos')
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
