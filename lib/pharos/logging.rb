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

    def self.no_debug!
      @debug = false
    end

    def self.format_exception(exc, severity = "ERROR")
      if !ENV['DEBUG'].to_s.empty? || severity == "DEBUG"
        backtrace = "\n    #{exc.backtrace.join("\n    ")}"
      end

      "Error: #{exc.message.strip}#{backtrace}"
    end

    def self.log_level
      @log_level ||= debug? ? Logger::DEBUG : Logger::INFO
    end

    def self.logger
      @logger ||= Logger.new($stdout).tap do |logger|
        logger.progname = 'API'
        logger.level = Pharos::Logging.log_level
        logger.formatter = proc do |severity, _datetime, _progname, msg|
          message = msg.is_a?(Exception) ? Pharos::Logging.format_exception(msg, severity) : msg
          "    %<msg>s\n" % { msg: message }
        end
      end
    end

    def logger
      Pharos::Logging.logger
    end
  end
end
