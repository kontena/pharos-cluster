# frozen_string_literal: true

module Pharos
  class Phase
    # @return [String]
    def self.title(title = nil)
      @title = title if title
      @title || name
    end

    def to_s
      "#{self.class.title} @ #{@host} (#{@host.role})"
    end

    def self.register_component(component)
      Pharos::Phases.register_component component
    end

    attr_reader :cluster_context

    # @param host [Pharos::Configuration::Host]
    # @param config [Pharos::Config]
    # @param ssh [Pharos::SSH::Client]
    # @param master [Pharos::Configuration::Host]
    def initialize(host, config: nil, ssh: nil, master: nil, cluster_context: nil)
      @host = host
      @config = config
      @ssh = ssh
      @master = master
      @cluster_context = cluster_context
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
      @ssh.exec_script!(
        script,
        env: vars,
        path: script_path(script)
      )
    end

    def parse_resource_file(path, vars = {})
      Pharos::YamlFile.new(resource_path(path)).read(vars)
    end

    %i(debug info warn error fatal puts).each do |meth|
      define_method meth do |msg|
        Out.send(meth, @host.to_s) { msg }
      end
      private meth
    end
  end
end
