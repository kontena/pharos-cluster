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
    # @param ssh [Pharos::SSH::Client]
    # @param master [Pharos::Configuration::Host]
    def initialize(host, config: nil, ssh: nil, master: nil, cluster_context: nil)
      @host = host
      @config = config
      @ssh = ssh
      @master = master
      @cluster_context = cluster_context
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
      @ssh.exec_script!(
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
      @host.configurer(@ssh)
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

    def process_hooks(state)
      return unless host.is_a?(Pharos::Configuration::Host)
      hooks = host.send(state)&.fetch(klass_title)
      return if hooks.nil?

      ssh_client = @ssh || Pharos::SSH::Manager.new.client_for(host)

      hooks = [hooks].compact unless hooks.is_a?(Array)
      return if hooks.empty?

      logger.info { "Running #{state} #{klass_title} hooks .." }
      hooks.each do |hook|
        case hook
        when Array
          ssh_client.exec!(hook.join(' '))
        when String
          ssh_client.exec!(hook)
        when Hash
          Dir.glob(hook['copy_from']).each do |local_file|
            to = File.join(hook['to'], File.basename(local_file))
            logger.info { "Uploading file #{local_file} to #{host.address}:#{to}" }
            ssh_client.file(to).write(File.open(local_file, 'r'))
          end
        end
        logger.info { "Running #{hook} .." }
      end
    end

    def run
      process_hooks(:before)
      call
    ensure
      process_hooks(:after)
    end

    def klass_title
      @klass_title ||= self.class.name.extend(Pharos::CoreExt::StringCasing).underscore.split('::').last
    end
  end
end
