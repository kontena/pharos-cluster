# frozen_string_literal: true

module Pharos
  module Configuration
    class OsRelease < Pharos::Configuration::Struct
      include Comparable

      attribute :id, Pharos::Types::Strict::String
      attribute :id_like, Pharos::Types::Strict::String.optional.default(nil)
      attribute :name, Pharos::Types::Strict::String.optional.default(nil)
      attribute :version, Pharos::Types::Strict::String

      def <=>(other)
        [id, version] <=> [other.id, other.version]
      end
    end
  end
end
