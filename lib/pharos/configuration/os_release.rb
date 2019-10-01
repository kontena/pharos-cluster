# frozen_string_literal: true

module Pharos
  module Configuration
    class OsRelease < Pharos::Configuration::Struct
      attribute :id, Pharos::Types::Strict::String
      attribute :id_like, Pharos::Types::Strict::String.optional.default(nil)
      attribute :name, Pharos::Types::Strict::String.optional.default(nil)
      attribute :version, Pharos::Types::Strict::String.optional.default(nil)
      attribute :version_regex, Pharos::Types.Instance(Regexp).optional.default(nil)

      def ==(other)
        return false unless id == other.id

        (version || version_regex) === other.version # rubocop:disable Style/CaseEquality
      end
    end
  end
end
