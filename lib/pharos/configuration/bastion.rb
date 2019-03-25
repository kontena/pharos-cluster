# frozen_string_literal: true

module Pharos
  module Configuration
    class Bastion < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
      attribute :ssh_port, Pharos::Types::Strict::Integer.default(22)
      attribute :ssh_proxy_command, Pharos::Types::Strict::String

      def host
        @host ||= Host.new(attributes)
      end

      def method_missing(meth, *args)
        host.respond_to?(meth) ? host.send(meth, *args) : super
      end

      def respond_to_missing?(meth, include_private = false)
        host.respond_to?(meth) || super
      end
    end
  end
end
