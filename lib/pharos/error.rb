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

  class ExecError < Error
    attr_reader :cmd, :exit_status, :output

    def initialize(cmd, exit_status, output)
      @cmd = cmd
      @exit_status = exit_status
      @output = if output.respond_to?(:string)
                  output.string
                elsif output.respond_to?(:read)
                  output.rewind
                  output.read
                else
                  output
                end
    end

    def message
      "exec failed with code #{@exit_status}: #{@cmd}\n#{@output}"
    end
  end
end
