# frozen_string_literal: true

require 'logger'

module Pharos
  class Phase
    PHASE_TITLE = nil

    # @return [String]
    def self.title(title = nil)
      @title = title if title
      @title || name
    end

    def to_s
      "#{self.class.title} @ #{@host}"
    end

    def self.register_component(component)
      Pharos::Phases.register_component component
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
        logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
        logger.formatter = proc do |_severity, _datetime, progname, msg|
          "    [%<progname>s] %<msg>s\n" % { progname: progname, msg: msg }
        end
      end
    end

    # @return [String]
    def script_path(*path)
      File.join(__dir__, 'scripts', *path)
    end

    # @return [String]
    def resource_path(*path)
      File.join(__dir__, 'resources', *path)
    end

    # @param script [String] name of file under ../scripts/
    def exec_script(script, vars = {})
      @ssh.exec_script!(script,
                        env: vars,
                        path: script_path(script))
    end

    def parse_resource_file(path, vars = {})
      Pharos::YamlFile.new(resource_path(path)).read(vars)
    end
  end
end
