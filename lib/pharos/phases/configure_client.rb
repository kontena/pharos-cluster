# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        save_config_locally
        config_map = previous_config_map
        if config_map
          cluster_context['previous-config-map'] = config_map
          cluster_context['previous-config'] = build_config(config_map)
        end
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

      # @param configmap [Kubeclient::Resource]
      # @return [Pharos::Config]
      def build_config(configmap)
        cluster_config = YAML.safe_load(configmap.data['cluster.yml'])
        cluster_config['hosts'] ||= []
        data = Pharos::ConfigSchema.build.call(cluster_config)
        Pharos::Config.new(data)
      end

      # @return [Kubeclient::Resource]
      def previous_config_map
        kube_client = Pharos::Kube.client(@host.api_address)
        kube_client.get_config_map('pharos-config', 'kube-system')
      rescue Kubeclient::ResourceNotFoundError
        nil
      end
    end
  end
end
