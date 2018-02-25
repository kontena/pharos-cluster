module Shokunin::Configuration
  class Host < Dry::Struct
    constructor_type :schema

    attribute :address, Shokunin::Types::Strict::String
    attribute :private_address, Shokunin::Types::Strict::String
    attribute :role, Shokunin::Types::Strict::String
    attribute :user, Shokunin::Types::Strict::String.default('ubuntu')
    attribute :ssh_key_path, Shokunin::Types::Strict::String.default('~/.ssh/id_rsa')
  end
end