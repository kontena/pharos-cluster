require_relative 'logging'

module Kupo::Phases
  class Base
    include Kupo::Phases::Logging

    REMOTE_OUTPUT_INDENT = (" " * 4).freeze

    def self.register_component(component)
      @@components ||= Set.new
      @@components << component
    end

    def self.components
      @@components
    end

    def debug?
      ENV['DEBUG'].to_s == 'true'
    end

    def remote_output(type, data)
      if debug?
        data.each_line { |line|
          print pastel.dim(REMOTE_OUTPUT_INDENT  + line)
        }
      end
    end

    def pastel
      @pastel ||= Pastel.new
    end
  end
end