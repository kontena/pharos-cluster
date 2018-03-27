# frozen_string_literal: true

require 'erb'
require 'ostruct'

module Kupo
  class Erb
    def initialize(path, content = nil)
      @path = path
      @content = content.respond_to?(:read) ? content.read : (content || File.read(path))
    end

    def render(vars = {})
      return @content unless erb?
      ERB.new(@content, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
    end

    private

    def erb?
      @path.is_a?(Symbol) || @path.end_with?('.erb')
    end
  end
end
