# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateHost < Pharos::Phase
      title "Validate hosts"

      def call
        logger.info { "Validating current role matches ..." }
        check_role
        logger.info { "Validating distro and version ..." }
        check_distro_version
        logger.info { "Validating host configuration ..." }
        check_cpu_arch
        logger.info { "Validating hostname uniqueness ..." }
        validate_unique_hostnames
      end

      def check_distro_version
        @host.configurer(@ssh) # load configurer
        return if Pharos::Host::Configurer.configs.any? { |config| config.supported_os?(@host.os_release) }

        raise Pharos::InvalidHostError, "Distro not supported: #{@host.os_release.name}"
      end

      def check_cpu_arch
        return if @host.cpu_arch.supported?
        raise Pharos::InvalidHostError, "Cpu architecture not supported: #{@host.cpu_arch.id}"
      end

      def check_role
        return if !@host.checks['kubelet_configured']

        raise Pharos::InvalidHostError, "Cannot change worker host role to master" if @host.master? && !@host.checks['ca_exists']
        raise Pharos::InvalidHostError, "Cannot change master host role to worker" if @host.worker? && @host.checks['ca_exists']

        logger.debug { "#{@host.role} role matches" }
      end

      def validate_unique_hostnames
        duplicates = @config.hosts.reject { |h| h.address == @host.address }.select { |h| h.hostname == @host.hostname }
        return if duplicates.empty?

        raise Pharos::InvalidHostError, "Duplicate hostname #{@host.hostname} for hosts #{duplicates.map(&:address).join(',')}"
      end
    end
  end
end
