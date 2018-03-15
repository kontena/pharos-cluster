# frozen_string_literal: true

require 'logger'

module Kupo::Phases::Logging
  def self.initialize_logger(log_target = $stdout, log_level = Logger::INFO)
    @logger = Logger.new(log_target)
    @logger.progname = 'API'
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : log_level
    logger.formatter = proc do |_severity, _datetime, _progname, msg|
      "    #{msg}\n"
    end

    @logger
  end

  def self.logger
    defined?(@logger) ? @logger : initialize_logger
  end

  def self.logger=(log)
    @logger = (log ? log : Logger.new('/dev/null'))
  end

  def logger
    Kupo::Phases::Logging.logger
  end
end
