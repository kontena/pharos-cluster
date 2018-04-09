# frozen_string_literal: true

require 'logger'
require_relative '../phases'

module Pharos
  module Phases
    class Base
      # @return [String]
      def self.title
        # XXX: prettier
        self.name
      end

      def self.register_component(component)
        Pharos::Phases.components << component
      end

      # @param host [Pharos::Configuration::Host]
      # @param config [Pharos::Config]
      # @param ssh [Pharos::SSH::Client]
      # @param master [Pharos::Configuration::Host]
      def initialize(host, config: nil, ssh: nil, master: nil)
        @host = host
        @config = config
        @ssh = ssh
        @master = master
      end

      def logger
        @logger ||= Logger.new($stdout).tap do |logger|
          logger.progname = "#{@host}"
          logger.level = ENV["DEBUG"] ? Logger::DEBUG : log_level
          logger.formatter = proc do |_severity, _datetime, progname, msg|
            "    [%<progname>s] %<msg>s\n" % { progname: progname, msg: msg }
          end
        end
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        @ssh.exec_script!(script,
                          env: vars,
                          path: File.realpath(File.join(__dir__, '..', 'scripts', script)))
      end

      def parse_resource_file(path, vars = {})
        path = File.realpath(File.join(__dir__, '..', 'resources', path))
        Pharos::YamlFile.new(path).read(vars)
      end
    end
  end
end
