module Kontadm::Configuration
  class Feature < Dry::Struct
    constructor_type :schema

    attribute :name, Kontadm::Types::Strict::String
    attribute :options, Kontadm::Types::Strict::Hash.optional
  end
end