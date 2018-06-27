# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateClusterHosts < Pharos::Phase
      title "Validate cluster hosts"

      def call
        validate_unique_hostnames
      end

      def validate_unique_hostnames
        logger.info { "Validating hostname uniqueness ..." }

        duplicates = @config.hosts.reject { |h| h.address == @host.address }.select { |h| h.hostname == @host.hostname }
        return if duplicates.empty?

        raise Pharos::InvalidHostError, "Duplicate hostname #{@host.hostname} for hosts #{duplicates.map(&:address).join(',')}"
      end
    end
  end
end
