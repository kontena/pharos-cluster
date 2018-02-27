require_relative 'logging'

module Shokunin::Phases
  class Base
    include Shokunin::Phases::Logging


    def self.register_component(component)
      @@components ||= Set.new
      @@components << component
    end

    def self.components
      @@components
    end
  end
end