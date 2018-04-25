# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateHostname < Pharos::Phase
      title "Validate unique hostnames for all hosts"

      # @param hosts Array<Pharos::Configuration::Host>
      def initialize(host, hosts:, **options)
        super(host, **options)
        @hosts = hosts
      end

      def call
        logger.info { "Validating hostname uniqueness ..." }

        duplicates  = @hosts.reject { |h| h.address == @host.address }.select { |h| h.hostname == @host.hostname }
        unless duplicates.empty?
          raise Pharos::InvalidHostError, "Duplicate hostname #{@host.hostname} for hosts #{duplicates.map{|h| h.address}.join(',')}"
        end
      end
    end
  end
end