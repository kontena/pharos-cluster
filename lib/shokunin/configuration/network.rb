module Shokunin::Configuration
  class Network < Dry::Struct
    constructor_type :schema

    attribute :trusted_subnets, Shokunin::Types::Array.member(Shokunin::Types::String)
  end
end