# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Kupo
  class Erb
    def initialize(path = nil)
      @path = path
    end

    def erb?
      File.fnmatch?('*.erb', @path)
    end

    def template
      File.read(@path)
    end

    def render(vars = {})
      if erb?
        template
      else
        ERB.new(template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
      end
    end
  end
end
