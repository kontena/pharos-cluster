# frozen_string_literal: true

module Pharos
  module Configuration
    class OsRelease < Dry::Struct
      constructor_type :schema

      SUPPORTED = {
        'ubuntu' => ['16.04']
      }.freeze

      attribute :id, Pharos::Types::Strict::String
      attribute :id_like, Pharos::Types::Strict::String
      attribute :name, Pharos::Types::Strict::String
      attribute :version, Pharos::Types::Strict::String

      def supported?
        distro = SUPPORTED[id]
        return false unless distro
        distro.any? { |v|
          version == v
        }
      end
    end
  end
end
