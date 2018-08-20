# frozen_string_literal: true

module Pharos
  module Configuration
    class OsRelease < Pharos::Configuration::Struct
      attribute :id, Pharos::Types::Strict::String
      attribute :id_like, Pharos::Types::Strict::String.optional.default(nil)
      attribute :name, Pharos::Types::Strict::String.optional.default(nil)
      attribute :version, Pharos::Types::Strict::String
    end
  end
end
