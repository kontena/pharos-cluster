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
        @host ||= Host.new(**attributes)
      end

      # @return [Net::SSH::Gateway]
      def gateway
        return @gateway if @gateway

        non_interactive = true
        @gateway ||= Net::SSH::Gateway.new(address, user, ssh_opts.merge(non_interactive: non_interactive))
      rescue *Pharos::Transport::SSH::RETRY_CONNECTION_ERRORS => exc
        raise if non_interactive == false || !$stdin.tty? # don't re-retry

        non_interactive = false
        retry
      end

      private

      def ssh_opts
        {}.tap do |opts|
          opts[:keys] = [ssh_key_path] if ssh_key_path
          opts[:port] = ssh_port
        end
      end
    end
  end
end
