# frozen_string_literal: true

require 'logger'
require 'concurrent'

module Pharos
  class Phase
    using Pharos::CoreExt::Colorize

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

    # @return [Hash{String => Concurrent::FixedThreadPool}]
    def self.worker_pools
      @worker_pools ||= {}
    end

    def self.cleanup
      worker_pools.values.each do |pool|
        next if pool.shutdown?

        pool.shutdown
        pool.wait_for_termination(10)
        pool.kill unless pool.shutdown?
      end
      worker_pools.clear
    end

    # @return [Mutex]
    def self.mutex
      @mutex ||= Mutex.new
    end

    attr_reader :cluster_context, :host

    # @param host [Pharos::Configuration::Host]
    # @param config [Pharos::Config]
    def initialize(host, config: nil, cluster_context: nil)
      @host = host
      @config = config
      @cluster_context = cluster_context
    end

    def transport
      @host.transport
    end

    FORMATTER_COLOR = proc do |severity, _datetime, hostname, msg|
      message = msg.is_a?(Exception) ? Pharos::Logging.format_exception(msg, severity) : msg

      color = case severity
              when "DEBUG" then :dim
              when "INFO" then :to_s
              when "WARN" then :yellow
              else :red
              end

      message.gsub(/^/m) { "    [#{hostname.send(color)}] " } + "\n"
    end

    FORMATTER_NO_COLOR = proc do |severity, _datetime, hostname, msg|
      message = msg.is_a?(Exception) ? Pharos::Logging.format_exception(msg, severity) : msg

      if severity == "INFO"
        message.gsub(/^/m) { "    [#{hostname}] " } + "\n"
      else
        message.gsub(/^/m) { "    [#{hostname}] [#{severity}] " } + "\n"
      end
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |logger|
        logger.progname = @host.to_s
        logger.level = Pharos::Logging.log_level
        logger.formatter = Pharos::CoreExt::Colorize.enabled? ? FORMATTER_COLOR : FORMATTER_NO_COLOR
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
      transport.exec_script!(
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

    # @return [Pharos::Configuration::Host]
    def master_host
      @config.master_host
    end

    # @return [K8s::Client]
    def kube_client
      cluster_context['kube_client'] || raise("No Kubernetes API client available")
    end

    # @return [Boolean] true if there's a configured kube_client available
    def kube_client?
      !!cluster_context['kube_client']
    end

    # @param name [String]
    # @param vars [Hash]
    def kube_stack(name, **vars)
      Pharos::Kube::Stack.load(name, File.join(RESOURCE_PATH, name), name: name, **vars)
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

    # @return [Mutex]
    def mutex
      self.class.mutex
    end

    # @return [Concurrent::FixedThreadPool]
    def worker_pool(name, size)
      self.class.worker_pools[name] ||= Concurrent::FixedThreadPool.new(size)
    end

    # Blocks until work is done via pool of workers
    # @param name [String]
    # @param size [Integer]
    def throttled_work(name, size, &block)
      size = 1 if size < 1
      task = Concurrent::Future.execute(executor: worker_pool(name, size), &block)
      raise(task.reason) if task.value.nil? && task.reason.is_a?(Exception)

      task.value
    end
  end
end
