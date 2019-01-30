# frozen_string_literal: true

require_relative 'addon'
require_relative 'logging'
require_relative 'kube'

module Pharos
  class AddonManager
    include Pharos::Logging
    using Pharos::CoreExt::DeepTransformKeys

    class InvalidConfig < Pharos::Error; end
    class UnknownAddon < Pharos::Error; end

    RETRY_ERRORS = [
      OpenSSL::SSL::SSLError,
      Excon::Error,
      K8s::Error
    ].freeze

    # @return [Array<Class<Pharos::Addon>>]
    def self.addons
      @addons ||= []
    end

    # @param dirs [Array<String>]
    # @return [Array<Class<Pharos::Addon>>]
    def self.load_addons(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*/**', 'addon.rb')).each { |f| require(f) }
      end

      addons
    end

    # @param config [Pharos::Configuration]
    # @param cluster_context [Hash]
    def initialize(config, cluster_context)
      @config = config
      @cluster_context = cluster_context
      enable_default_addons
    end

    def enable_default_addons
      addon_classes.each do |addon|
        if addon.enabled?
          configs[addon.addon_name] ||= {}
          configs[addon.addon_name]['enabled'] = true
        end
      end
    end

    def configs
      @configs ||= @config.addons.sort_by { |name, _config|
        addon_class = addon_classes.find { |a| a.addon_name == name }
        raise UnknownAddon, "unknown addon: #{name}" if addon_class.nil?
        addon_class.priority
      }.to_h.deep_stringify_keys
    end

    def prev_configs
      if config = @cluster_context['previous-config']
        config.addons
      else
        {}
      end
    end

    # @return [Array<Class<Pharos::Addon>>]
    def addon_classes
      self.class.addons
    end

    def validate
      with_enabled_addons do |addon_class, config|
        outcome = addon_class.validate(config)
        unless outcome.success?
          raise InvalidConfig, YAML.dump(addon_class.addon_name => outcome.errors.deep_stringify_keys).gsub(/^---$/, '')
        end
      end
    end

    # @return [K8s::Client]
    def kube_client
      if !@kubeclient && @cluster_context['kubeconfig']
        @kube_client = @config.kube_client(@cluster_context['kubeconfig'])
      end
      @kube_client
    end

    def options
      {
        kube_client: kube_client,
        cpu_arch: @config.master_host.cpu_arch, # needs to be resolved *after* Phases::ValidateHost runs
        cluster_config: @config
      }
    end

    def each(&block)
      with_enabled_addons do |addon_class, config_hash|
        config = addon_class.validate(config_hash)
        addon = addon_class.new(config, enabled: true, **options)
        addon.validate
        Retry.perform(yield_object: addon, logger: logger, &block)
      end

      with_disabled_addons do |addon_class|
        Retry.perform(yield_object: addon_class.new(nil, enabled: false, **options), logger: logger, &block)
      end
    end

    def with_enabled_addons
      configs.each do |name, config|
        klass = addon_classes.find { |a| a.addon_name == name }
        if klass && config['enabled']
          yield(klass, config)
        end
      end
    end

    def with_disabled_addons
      addon_classes.select { |addon_class|
        prev_config = prev_configs[addon_class.addon_name]
        config = configs[addon_class.addon_name]
        prev_config && prev_config['enabled'] && (config.nil? || !config['enabled'])
      }.each do |addon_class|
        yield(addon_class)
      end
    end
  end
end
