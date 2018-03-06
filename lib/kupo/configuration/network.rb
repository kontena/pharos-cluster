module Kupo::Configuration
  class Network < Dry::Struct
    constructor_type :schema

    attribute :service_cidr, Kupo::Types::String.default('10.96.0.0/12')
    attribute :pod_network_cidr, Kupo::Types::String.default('10.32.0.0/12')
    attribute :trusted_subnets, Kupo::Types::Array.member(Kupo::Types::String)
  end
end