module Kontadm::Configuration::Feature
  class Network < Dry::Struct
    constructor_type :schema

    attribute :settings, Kontadm::Types::Hash.schema(
      trusted_subnets: Kontadm::Types::Array.member(Kontadm::Types::String)
    )
  end
end