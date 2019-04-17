# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureFirewalld < Pharos::Phase
      title "Configure firewalld"

      def call
        if @config.network&.firewalld&.enabled
          configure_firewalld
        else
          disable_firewalld
        end
      end

      def configure_firewalld
        logger.info { 'Configuring firewalld packages ...' }
        @host.configurer.configure_firewalld

        logger.info { 'Configuring firewalld rules ...' }

        write_config('services/pharos-master.xml', pharos_master_service) if @host.master?
        write_config('services/pharos-worker.xml', pharos_worker_service)
        write_config('ipsets/pharos.xml', pharos_ipset)

        return unless firewalld_reload?

        cluster_context['reload-iptables'] = true unless @host.new?
        logger.info { 'Reloading firewalld ...' }
        exec_script(
          'configure-firewalld.sh',
          ROLE: @host.role
        )
      end

      def firewalld_reload?
        !!@firewalld_reload
      end

      def disable_firewalld
        logger.info { 'Firewalld not enabled, disabling ...' }
        exec_script('disable-firewalld.sh')
      end

      # @param file [String]
      # @param contents [String]
      def write_config(file, contents)
        remote_file = transport.file(File.join('/etc/firewalld/', file))
        return if remote_file.exist? && remote_file.read.strip == contents.strip

        @firewalld_reload = true
        remote_file.write(contents)
      end

      # @return [Array<String>]
      def trusted_addresses
        addresses = @config.hosts.flat_map { |host|
          [host.address, host.private_address, host.private_interface_address].compact.uniq
        }
        addresses += [@config.network.pod_network_cidr, @config.network.service_cidr]
        addresses += @config.network.firewalld.trusted_subnets if @config.network.firewalld&.trusted_subnets

        addresses
      end

      # @param role [String]
      # @return [Array<Pharos::Configuration::Network::Firewall::Port]
      def open_ports(role)
        @config.network.firewalld.open_ports.select { |port|
          port.roles.include?('*') || port.roles.include?(role)
        }
      end

      # @return [String]
      def pharos_master_service
        parse_resource_file(
          'firewalld/service.xml.erb',
          name: 'pharos-master',
          description: 'Kontena Pharos master host service',
          ports: open_ports('master').map(&:to_h)
        )
      end

      # @return [String]
      def pharos_worker_service
        parse_resource_file(
          'firewalld/service.xml.erb',
          name: 'pharos-worker',
          description: 'Kontena Pharos worker host service',
          ports: open_ports('worker').map(&:to_h)
        )
      end

      # @return [String]
      def pharos_ipset
        parse_resource_file(
          'firewalld/ipset.xml.erb',
          name: 'pharos',
          entries: trusted_addresses
        )
      end
    end
  end
end
