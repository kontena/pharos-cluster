# frozen_string_literal: true

require 'logger'

module Pharos
  module Logging
    include Pharos::Debug.module

    def self.logger
      @logger
    end

    def self.logger=(log)
      @logger = log || Logger.new('/dev/null')
    end

    FORMATTER = "    %s\n"

    def self.log_target
      @log_target ||= ENV["PHAROS_LOG"].to_s.empty? ? $stdout : ENV["PHAROS_LOG"]
    end

    def self.__init__
      Pharos::Logging.logger = Logger.new(log_target).tap do |logger|
        logger.progname = 'API'
        logger.level = Logger.const_get(LOG_LEVEL)
        if log_target&.isatty
          logger.formatter = proc do |_severity, _datetime, _progname, msg|
            FORMATTER % msg
          end
        end
      end
    end

    __init__ unless defined?(@logger)

    private

    def logger
      Pharos::Logging.logger
    end
  end
end
