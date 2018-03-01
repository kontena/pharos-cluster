module Kupo::Configuration
  class Network < Dry::Struct
    constructor_type :schema

    attribute :trusted_subnets, Kupo::Types::Array.member(Kupo::Types::String)
  end
end