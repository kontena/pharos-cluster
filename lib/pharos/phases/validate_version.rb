# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateVersion < Pharos::Phase
      title "Validate cluster version"

      REMOTE_KUBECONFIG = "/etc/kubernetes/admin.conf"

      def call
        return unless kubeconfig?

        if @host.master_sort_score.positive?
          logger.warn { "Master seems unhealthy, can't detect cluster version." }
          return
        end

        cluster_context['kubeconfig'] = kubeconfig
        config_map = previous_config_map
        if config_map
          existing_version = config_map.data['pharos-version']
          cluster_context['existing-pharos-version'] = existing_version
          validate_version(existing_version)
        else
          logger.info { 'No version detected' }
        end
      end

      # @param cluster_version [String]
      def validate_version(cluster_version)
        cluster_version = Gem::Version.new(cluster_version.gsub(/\+.*/, ''))
        raise "Downgrade not supported" if cluster_version > pharos_version

        if requirement.satisfied_by?(cluster_version)
          logger.info { "Valid cluster version detected: #{cluster_version}" }
        else
          logger.warn { "Invalid cluster version detected: #{cluster_version}" }
          cluster_context['unsafe_upgrade'] = true
        end
      end

      # @return [String]
      def kubeconfig?
        ssh.file(REMOTE_KUBECONFIG).exist?
      end

      # @return [String]
      def read_kubeconfig
        ssh.file(REMOTE_KUBECONFIG).read
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

      private

      def pharos_version
        @pharos_version ||= Gem::Version.new(Pharos::VERSION)
      end

      # Returns a requirement like "~>", "1.3.0"  which will match >= 1.3.0 && < 1.4.0
      def requirement
        Gem::Requirement.new('~>' + pharos_version.segments.first(2).join('.') + (pharos_version.prerelease? ? '.0-a' : '.0'))
      end
    end
  end
end
