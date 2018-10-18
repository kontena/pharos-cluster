# frozen_string_literal: true

module Pharos
  class Error < StandardError; end
  class InvalidHostError < Error; end
  class InvalidAddonError < Error; end

  class ConfigError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end

    def to_s
      "Invalid configuration:\n#{YAML.dump(@errors)}"
    end
  end
end
