# frozen_string_literal: true

require 'dry-struct'

module Pharos
  module Phases
    class Component < Dry::Struct
      constructor_type :schema

      attribute :name, Pharos::Types::String
      attribute :version, Pharos::Types::String
      attribute :license, Pharos::Types::String
    end
  end
end
