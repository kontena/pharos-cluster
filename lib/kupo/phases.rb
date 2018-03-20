# frozen_string_literal: true

module Kupo
  module Phases

    # List of registered components
    # @return [Set]
    def self.components
      @components ||= Set.new
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
