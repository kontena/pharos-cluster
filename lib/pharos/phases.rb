# frozen_string_literal: true

require 'dry-struct'
require 'ostruct'

module Pharos
  module Phases
    class Component < Dry::Struct
      constructor_type :schema

      attribute :name, Pharos::Types::String
      attribute :version, Pharos::Types::String
      attribute :license, Pharos::Types::String
    end

    class ComponentRegistry < OpenStruct
      def sort_by(&block)
        @table.values.sort_by(&block)
      end
    end

    # List of registered components
    # @return [ComponentRegistry]
    def self.components
      @components ||= ComponentRegistry.new
    end
  end
end
