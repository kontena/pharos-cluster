# frozen_string_literal: true

module Pharos
  module Configuration
    class Bastion < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String

      alias to_s address

      def host
        Host.new(address: address, user: user, ssh_key_path: ssh_key_path)
      end
    end
  end
end
