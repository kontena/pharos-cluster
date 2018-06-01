# frozen_string_literal: true

module Pharos
  module Configuration
    class Taint < Dry::Struct
      constructor_type :schema

      attribute :key, Pharos::Types::String
      attribute :value, Pharos::Types::String
      attribute :effect, Pharos::Types::String
    end
  end
end
