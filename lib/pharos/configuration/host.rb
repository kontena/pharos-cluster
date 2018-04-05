# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'

module Pharos
  module Configuration
    class Host < Dry::Struct
      constructor_type :schema

      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :user, Pharos::Types::Strict::String.default('ubuntu')
      attribute :ssh_key_path, Pharos::Types::Strict::String.default('~/.ssh/id_rsa')
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')

      attr_accessor :os_release, :cpu_arch, :hostname
    end
  end
end
