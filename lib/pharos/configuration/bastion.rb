# frozen_string_literal: true

module Pharos
  module Configuration
    class Bastion < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
      attribute :ssh_proxy_command, Pharos::Types::Strict::String
      attribute :ssh_port, Pharos::Types::Strict::Integer.default(22)

      attr_writer :host

      def ==(other)
        return false unless other.respond_to?(:attributes)

        attributes.all? { |k, v| other.attributes[k] == v }
      end

      def host
        @host ||= Host.new(attributes)
      end
    end
  end
end
