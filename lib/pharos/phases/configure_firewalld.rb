# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureFirewalld < Pharos::Phase
      title "Configure firewalld"

      def call
        logger.info { 'Configuring firewalld rules ...' }

        write_config('services/pharos-master.xml', pharos_master_service) if @host.master?
        write_config('services/pharos-worker.xml', pharos_worker_service)
        write_config('ipsets/pharos.xml', pharos_ipset)

        exec_script(
          'configure-firewalld.sh',
          ROLE: @host.role
        )
      end

      # @param file [String]
      # @param contents [String]
      def write_config(file, contents)
        @host.ssh.file(File.join('/etc/firewalld/', file)).write(contents)
      end

      # @return [Array<String>]
      def trusted_addresses
        @config.hosts.flat_map { |host|
          [host.address, host.private_address, host.private_interface_address].compact.uniq
        }
      end

      # @return [String]
      def pharos_master_service
        parse_resource_file(
          'firewalld/service.xml.erb',
          name: 'pharos-master',
          description: 'Kontena Pharos master host service',
          ports: [
            { port: 6443, protocol: 'tcp' },
            { port: 22, protocol: 'tcp' }
          ]
        )
      end

      # @return [String]
      def pharos_worker_service
        parse_resource_file(
          'firewalld/service.xml.erb',
          name: 'pharos-worker',
          description: 'Kontena Pharos worker host service',
          ports: [
            { port: 80, protocol: 'tcp' },
            { port: 443, protocol: 'tcp' }
          ]
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
