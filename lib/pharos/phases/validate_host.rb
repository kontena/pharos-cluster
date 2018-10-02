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
        logger.info { "Validating host routes ..." }
        validate_routes
      end

      def check_distro_version
        if host_configurer.nil?
          raise Pharos::InvalidHostError, "Distro not supported: #{@host.os_release.name} #{@host.os_release.inspect}"
        end
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

      # @param cidr [String]
      # @return [nil, Array<Pharos::Configuration::Host::Route>]
      def overlapping_host_routes?(cidr)
        routes = @config.network.filter_host_routes(@host.overlapping_routes(cidr))

        return nil if routes.empty?

        routes
      end

      def validate_routes
        # rubocop:disable Style/GuardClause
        if routes = overlapping_host_routes?(@config.network.pod_network_cidr)
          fail "Overlapping host routes for .network.pod_network_cidr=#{@config.network.pod_network_cidr}: #{routes.join '; '}"
        end

        if routes = overlapping_host_routes?(@config.network.service_cidr)
          fail "Overlapping host routes for .network.service_cidr=#{@config.network.service_cidr}: #{routes.join '; '}"
        end
        # rubocop:enable Style/GuardClause
      end
    end
  end
end
