# frozen_string_literal: true

require 'logger'

module Pharos
  class Phase
    RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, 'resources'))).freeze

    # @return [String]
    def self.title(title = nil)
      @title = title if title
      @title || name
    end

    def to_s
      "#{self.class.title} @ #{@host}"
    end

    def self.register_component(component)
      Pharos::Phases.register_component(component)
    end

    attr_reader :cluster_context, :host

    # @param host [Pharos::Configuration::Host]
    # @param config [Pharos::Config]
    # @param master [Pharos::Configuration::Host]
    def initialize(host, config: nil, master: nil, cluster_context: nil)
      @host = host
      @config = config
      @master = master
      @cluster_context = cluster_context
    end

    def ssh
      @host.ssh
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |logger|
        logger.progname = @host.to_s
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
    # @param vars [Hash]
    def exec_script(script, vars = {})
      ssh.exec_script!(
        script,
        env: vars,
        path: script_path(script)
      )
    end

    # @param path [String]
    # @param vars [Hash]
    # @return [Pharos::YamlFile]
    def parse_resource_file(path, vars = {})
      Pharos::YamlFile.new(resource_path(path)).read(vars)
    end

    # @return [Pharos::Host::Configurer]
    def host_configurer
      @host_configurer ||= @host.configurer
    end

    # @return [Pharos::SSH::Client]
    def master_ssh
      return cluster_context['master-ssh'] if cluster_context['master-ssh']
      fail "Phase #{self.class.name} does not have master ssh"
    end

    # @return [K8s::Client]
    def kube_client
      fail "Phase #{self.class.name} does not have kubeconfig cluster_context" unless cluster_context['kubeconfig']

      @config.kube_client(cluster_context['kubeconfig'])
    end

    # @param name [String]
    # @param vars [Hash]
    def kube_stack(name, **vars)
      Pharos::Kube.stack(name, File.join(RESOURCE_PATH, name), name: name, **vars)
    end

    # @param name [String]
    # @param vars [Hash]
    def apply_stack(name, **vars)
      kube_stack(name, **vars).apply(kube_client)
    end

    # @param name [String]
    # @return [Array<K8s::Resource>]
    def delete_stack(name)
      Pharos::Kube::Stack.new(name).delete(kube_client)
    end

    def mutex
      self.class.mutex
    end

    def self.mutex
      @mutex ||= Mutex.new
    end
  end
end
