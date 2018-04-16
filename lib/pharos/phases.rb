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

    # List of registered components
    # @return [Set]
    def self.components
      @components ||= Set.new
    end

    def self.register_component(component)
      components << component
    end

    # Finds a component using arguments provided in a sym: value hash
    # @param [Hash] search_argument For example { name: 'kubernetes' }
    def self.find_component(search_arg)
      components.find do |component|
        search_arg.all? { |k, v| component.send(k) == v }
      end
    end
  end
end
