# frozen_string_literal: true

require 'logger'

module Pharos
  module Logging
    def self.debug?
      !!@debug
    end

    def self.debug!
      @debug = true
    end

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

    def self.log_level
      @log_level ||= debug? ? Logger::DEBUG : Logger::INFO
    end

    def self.logger
      @logger ||= Logger.new($stdout).tap do |logger|
        logger.progname = 'API'
        logger.level = Pharos::Logging.log_level
        logger.formatter = proc do |_severity, _datetime, _progname, msg|
          "    %<msg>s\n" % { msg: msg }
        end
      end
    end

    def logger
      Pharos::Logging.logger
    end
  end
end
