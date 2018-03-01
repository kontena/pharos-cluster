require_relative 'logging'

module Kupo::Phases
  class Base
    include Kupo::Phases::Logging


    def self.register_component(component)
      @@components ||= Set.new
      @@components << component
    end

    def self.components
      @@components
    end
  end
end