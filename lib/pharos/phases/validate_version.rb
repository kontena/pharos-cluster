# frozen_string_literal: true

require_relative "mixins/cluster_version"

module Pharos
  module Phases
    class ValidateVersion < Pharos::Phase
      title "Validate cluster version"

      include Pharos::Phases::Mixins::ClusterVersion

      def call
        return unless cluster_context['previous-config-map']

        if existing_version = cluster_context['previous-config-map'].data['pharos-version']
          cluster_context['existing-pharos-version'] = existing_version
          validate_version(existing_version)
        else
          logger.info { 'No version detected' }
        end
      end

      # @param cluster_version [String]
      def validate_version(cluster_version)
        cluster_version = build_version(cluster_version)
        raise "Downgrade not supported" if cluster_version > pharos_version

        if requirement.satisfied_by?(cluster_version)
          logger.info { "Valid cluster version detected: #{cluster_version}" }
        else
          logger.warn { "Invalid cluster version detected: #{cluster_version}" }
          cluster_context['unsafe_upgrade'] = true
        end
      end

      private

      # Returns a requirement like "~>", "1.3.0"  which will match >= 1.3.0 && < 1.4.0
      def requirement
        Gem::Requirement.new('~>' + pharos_version.segments.first(2).join('.') + (pharos_version.prerelease? ? '.0-a' : '.0'))
      end
    end
  end
end
