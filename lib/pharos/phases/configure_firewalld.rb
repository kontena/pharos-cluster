# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureFirewalld < Pharos::Phase
      title "Configure firewalld"

      def call
        logger.info { 'Configuring firewalld rules ...' }
        exec_script(
          'configure-firewalld.sh',
          ROLE: @host.role,
          PEER_ADDRESSES: trusted_addresses.join("\n")
        )
      end

      # @return [Array<String>]
      def trusted_addresses
        @config.hosts.flat_map { |host|
          [host.address, host.private_address, host.private_interface_address].compact.uniq
        }
      end
    end
  end
end
