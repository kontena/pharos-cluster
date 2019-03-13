# frozen_string_literal: true

require 'logger'

module Pharos
  module Logging
    def self.format_exception(exc, severity = "ERROR")
      return exc unless exc.is_a?(Exception)

      if ENV["DEBUG"] || severity == "DEBUG"
        message = exc.message.strip
        backtrace = "\n    #{exc.backtrace.join("\n    ")}"
      else
        message = exc.message[/\A(.+?)$/m, 1]
        backtrace = nil
      end

      "Error: #{message}#{backtrace}"
    end

    def self.initialize_logger(log_target = $stdout, log_level = Logger::INFO)
      @logger = Logger.new(log_target)
      @logger.progname = 'API'
      @logger.level = ENV["DEBUG"] ? Logger::DEBUG : log_level
      logger.formatter = proc do |severity, _datetime, _progname, msg|
        "    %<msg>s\n" % { msg: Pharos::Logging.format_exception(msg, severity) }
      end

      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : initialize_logger
    end

    def self.logger=(log)
      @logger = log || Logger.new('/dev/null')
    end

    def logger
      Pharos::Logging.logger
    end
  end
end
