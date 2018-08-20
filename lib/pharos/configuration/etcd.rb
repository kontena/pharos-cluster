# frozen_string_literal: true

module Pharos
  module Configuration
    class Etcd < Pharos::Configuration::Struct
      attribute :endpoints, Pharos::Types::Array.of(Pharos::Types::String)
      attribute :version, Pharos::Types::String
      attribute :certificate, Pharos::Types::String
      attribute :key, Pharos::Types::String
      attribute :ca_certificate, Pharos::Types::String
    end
  end
end
