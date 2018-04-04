# frozen_string_literal: true

require 'logger'

module Pharos
  module Phases
    module Logging
      def self.logger
        @logger
      end

      def self.logger=(log)
        @logger = (log ? log : Logger.new('/dev/null'))
      end

      def logger
        Pharos::Phases::Logging.logger
      end

      def self.__init__
        @logger = Logger.new($stdout).tap do |logger|
          logger.progname = 'API'
          logger.level = Pharos::Debug.module.const_get(:LOG_LEVEL)
          logger.formatter = proc do |_severity, _datetime, _progname, msg|
            "    #{msg}\n"
          end
        end
      end

      __init__ unless defined?(@logger)
    end
  end
end
