# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Pharos
  class Erb
    def initialize(template)
      @template = template
    end

    def render(vars = {})
      ERB.new(@template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
    end
  end
end
