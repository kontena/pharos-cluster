# frozen_string_literal: true

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
        @gateway ||= Net::SSH::Gateway.new(address, user, ssh_opts)
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
