# frozen_string_literal: true

module Kupo
  module Configuration
    class Network < Dry::Struct
      constructor_type :schema

      attribute :dns_replicas, Kupo::Types::Int
      attribute :service_cidr, Kupo::Types::String.default('10.96.0.0/12')
      attribute :pod_network_cidr, Kupo::Types::String.default('10.32.0.0/12')
      attribute :trusted_subnets, Kupo::Types::Array.member(Kupo::Types::String)
    end
  end
end
