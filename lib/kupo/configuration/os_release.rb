module Kupo::Configuration
  class OsRelease < Dry::Struct
    constructor_type :schema

    SUPPORTED = {
      'ubuntu' => ['16.04']
    }

    attribute :id, Kupo::Types::Strict::String
    attribute :id_like, Kupo::Types::Strict::String
    attribute :name, Kupo::Types::Strict::String
    attribute :version, Kupo::Types::Strict::String


    def supported?
      distro = SUPPORTED[self.id]
      return false unless distro
      distro.any? { |v|
        self.version == v
      }
    end
  end
end