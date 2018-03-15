# frozen_string_literal: true

module Kupo::Configuration
  class OsRelease < Dry::Struct
    constructor_type :schema

    SUPPORTED = {
      'ubuntu' => ['16.04']
    }.freeze

    attribute :id, Kupo::Types::Strict::String
    attribute :id_like, Kupo::Types::Strict::String
    attribute :name, Kupo::Types::Strict::String
    attribute :version, Kupo::Types::Strict::String

    def supported?
      distro = SUPPORTED[id]
      return false unless distro
      distro.any? { |v|
        version == v
      }
    end
  end
end
