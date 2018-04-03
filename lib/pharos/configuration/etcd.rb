# frozen_string_literal: true

module Pharos
  module Configuration
    class Etcd < Dry::Struct
      constructor_type :schema

      attribute :endpoints, Pharos::Types::Array.member(Pharos::Types::String)
      attribute :version, Pharos::Types::String
      attribute :certificate, Pharos::Types::String
      attribute :key, Pharos::Types::String
      attribute :ca_certificate, Pharos::Types::String
    end
  end
end
