# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Kupo
  class Erb
    def initialize(template, path: )
      @template = template
      @path = path
    end

    def render(vars = {})
      erb = ERB.new(@template, nil, '%<>-')
      erb.location = [@path, nil]
      erb.result(OpenStruct.new(vars).instance_eval { binding })
    end
  end
end
