# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateVersion < Pharos::Phase
      # @param cluster_version [String]
      def validate_version(cluster_version)
        cluster_major, cluster_minor, cluster_patch = cluster_version.split('.')
        major, minor, patch = Pharos::VERSION.split('.')

        if major.to_i < cluster_major.to_i || minor.to_i < cluster_minor.to_i || patch.to_i < cluster_patch.to_i
          raise "Downgrade not supported"
        end

        logger.info { "Valid cluster version detected: #{cluster_version}" }
      end
    end
  end
end
