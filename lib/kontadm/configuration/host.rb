module Kontadm::Configuration
  class Host < Dry::Struct
    constructor_type :schema

    attribute :address, Kontadm::Types::Strict::String
    attribute :role, Kontadm::Types::Strict::String
    attribute :user, Kontadm::Types::Strict::String.default('ubuntu')
    attribute :ssh_key_path, Kontadm::Types::Strict::String.default('~/.ssh/id_rsa')
  end
end