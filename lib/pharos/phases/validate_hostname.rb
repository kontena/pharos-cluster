# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateHostname < Pharos::Phase
      title "Validate unique hostnames for all hosts"

      def call
        logger.info { "Validating hostname uniqueness ..." }

        duplicates = @config.hosts.reject { |h| h.address == @host.address }.select { |h| h.hostname == @host.hostname }
        return if duplicates.empty?

        raise Pharos::InvalidHostError, "Duplicate hostname #{@host.hostname} for hosts #{duplicates.map(&:address).join(',')}"
      end
    end
  end
end
