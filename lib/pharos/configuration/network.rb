# frozen_string_literal: true

require 'ipaddr'

module Pharos
  module Configuration
    class Network < Dry::Struct
      constructor_type :schema

      class Weave < Dry::Struct
        constructor_type :schema

        attribute :trusted_subnets, Pharos::Types::Array.member(Pharos::Types::String)
      end

      class Calico < Dry::Struct
        constructor_type :schema
      end

      attribute :provider, Pharos::Types::String.default('weave')
      attribute :dns_replicas, Pharos::Types::Int
      attribute :service_cidr, Pharos::Types::String.default('10.96.0.0/12')
      attribute :pod_network_cidr, Pharos::Types::String.default('10.32.0.0/12')
      attribute :weave, Weave
      attribute :calico, Calico

      # @return [String] 10.96.0.10
      def dns_service_ip
        (IPAddr.new(service_cidr) | 10).to_s
      end
    end
  end
end
