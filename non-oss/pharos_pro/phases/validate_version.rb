# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateVersion < Pharos::Phase
      # @param cluster_version [String]
      def validate_version(cluster_version)
        raise "Downgrade not supported" if Gem::Version.new(cluster_version.gsub(/\+.*/, '')) > pharos_version

        logger.info { "Valid cluster version detected: #{cluster_version}" }
      end
    end
  end
end
