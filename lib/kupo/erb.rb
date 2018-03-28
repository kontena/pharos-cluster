# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Kupo
  class Erb
    def initialize(path)
      @path = path
    end

    def render(vars = {})
      return content unless erb?
      ERB.new(content, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
    end

    private

    def content
      File.read(@path)
    end

    def erb?
      @path.end_with?('.erb')
    end
  end
end
