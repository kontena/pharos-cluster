module Shokunin::Configuration::Feature
  class Network < Dry::Struct
    constructor_type :schema

    attribute :settings, Shokunin::Types::Hash.schema(
      trusted_subnets: Shokunin::Types::Array.member(Shokunin::Types::String)
    )
  end
end