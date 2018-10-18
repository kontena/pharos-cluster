# frozen_string_literal: true

module Pharos
  module Configuration
    class Taint < Pharos::Configuration::Struct
      attribute :key, Pharos::Types::String
      attribute :value, Pharos::Types::String
      attribute :effect, Pharos::Types::String
    end
  end
end
