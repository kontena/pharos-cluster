# frozen_string_literal: true

module Pharos
  module Configuration
    class Bastion < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
      attribute :ssh_port, Pharos::Types::Strict::Integer.default(22)

      attr_writer :host

      # Returns true when all attributes of the instance match the hash. Extra keys in the hash will be ignored.
      # @param other [Hash]
      # @return [Boolean]
      def attributes_match?(other)
        attributes.all? { |key, value| other[key] == value }
      end

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
