# frozen_string_literal: true

require 'net/ssh/gateway'

module Pharos
  module Configuration
    class Bastion < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
      attribute :ssh_port, Pharos::Types::Strict::Integer.default(22)

      def host
        @host ||= Host.new(attributes)
      end

      def gateway
        return @gateway if @gateway

        non_interactive = true
        @gateway = Net::SSH::Gateway.new(host.address, host.user, host.ssh_options)
      rescue *Pharos::Transport::SSH::RETRY_CONNECTION_ERRORS
        raise if non_interactive == false || !$stdin.tty?

        non_interactive = false
        retry
      end
    end
  end
end
