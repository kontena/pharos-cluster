require_relative 'os_release'
require_relative 'cpu_arch'

module Kupo::Configuration
  class Host < Dry::Struct
    constructor_type :schema

    attribute :address, Kupo::Types::Strict::String
    attribute :private_address, Kupo::Types::Strict::String
    attribute :role, Kupo::Types::Strict::String
    attribute :labels, Kupo::Types::Strict::Hash
    attribute :user, Kupo::Types::Strict::String.default('ubuntu')
    attribute :ssh_key_path, Kupo::Types::Strict::String.default('~/.ssh/id_rsa')
    attribute :container_engine, Kupo::Types::Strict::String.default('cri-o')

    attr_accessor :os_release
    attr_accessor :cpu_arch
  end
end