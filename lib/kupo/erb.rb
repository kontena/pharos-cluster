# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Kupo
  class Erb
    def initialize(path)
      @path = path
    end

    def render(vars = {})
      if erb?
        ERB.new(template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
      else
        template
      end
    end

    private

    def erb?
      @path.end_with?('.erb')
    end

    def template
      File.read(@path)
    end
  end
end
