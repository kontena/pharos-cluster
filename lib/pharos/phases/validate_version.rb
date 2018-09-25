# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateVersion < Pharos::Phase
      title "Validate cluster version"

      REMOTE_KUBECONFIG = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig?

        cluster_context['kubeconfig'] = kubeconfig
        config_map = previous_config_map
        if config_map
          validate_version(config_map.data['pharos-version'])
        else
          logger.info { 'No version detected' }
        end
      end

      # @param cluster_version [String]
      def validate_version(cluster_version)
        cluster_major, cluster_minor, cluster_patch = cluster_version.split('.')
        major, minor, patch = Pharos::VERSION.split('.')
        unless cluster_major == major && cluster_minor == minor
          raise "Upgrade path not supported"
        end

        if cluster_patch.to_i <= patch.to_i
          raise "Downgrade not supported"
        end

        logger.info { "Valid cluster version detected: #{cluster_version}" }
      end

      # @return [String]
      def kubeconfig?
        @ssh.file(REMOTE_KUBECONFIG).exist?
      end

      # @return [String]
      def read_kubeconfig
        @ssh.file(REMOTE_KUBECONFIG).read
      end

      # @return [Hash]
      def kubeconfig
        logger.debug { "Fetching kubectl config ..." }
        config = Pharos::Kube::Config.new(read_kubeconfig)
        config.update_server_address(@host.api_address)

        logger.debug { "New config: #{config}" }
        config.to_h
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
