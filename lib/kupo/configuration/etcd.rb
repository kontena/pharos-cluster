# frozen_string_literal: true

module Kupo
  module Configuration
    class Etcd < Dry::Struct
      constructor_type :schema

      attribute :endpoints, Kupo::Types::Array.member(Kupo::Types::String)
      attribute :version, Kupo::Types::String
      attribute :certificate, Kupo::Types::String
      attribute :key, Kupo::Types::String
      attribute :ca_certificate, Kupo::Types::String
    end
  end
end
