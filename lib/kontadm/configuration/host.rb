module Kontadm::Configuration
  class Host < Dry::Struct
    constructor_type :schema

    attribute :address, Kontadm::Types::Strict::String
    attribute :user, Kontadm::Types::Strict::String.default('ubuntu')
    attribute :role, Kontadm::Types::Strict::String
  end
end