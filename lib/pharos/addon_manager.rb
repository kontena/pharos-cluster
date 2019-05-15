# frozen_string_literal: true

require_relative 'addon'
require_relative 'addon_context'
require_relative 'logging'
require_relative 'kube'

module Pharos
  class AddonManager
    using Pharos::CoreExt::StringCasing
    using Pharos::CoreExt::DeepTransformKeys
    using Pharos::CoreExt::Colorize

    include Pharos::Logging

    class InvalidConfig < Pharos::Error; end
    class UnknownAddon < Pharos::Error; end

    RETRY_ERRORS = [
      OpenSSL::SSL::SSLError,
      Excon::Error,
      K8s::Error
    ].freeze

    # @return [Hash<String => Class<Pharos::Addon>>]
    def self.addons
      @addons ||= {}
    end

    # @return [Array<Pharos::Addon>]
    def self.addon_classes
      addons.values
    end

    # @param dirs [Array<String>]
    # @return [Array<Class<Pharos::Addon>>]
    def self.load_addons(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*/**', 'addon.rb')).each do |f|
          load_addon(f)
        end
      end

      addons
    end

    # @param file [String]
    def self.load_addon(file)
      source = File.read(file)
      Pharos::AddonContext.new.context.instance_eval(source, file)
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
      self.class.addon_classes
    end

    # @param name [String]
    # @return [Pharos::Addon,nil]
    def find_addon(name)
      self.class.addons[name]
    end

    def validate
      with_enabled_addons do |addon_class, config|
        outcome = addon_class.validate(config)
        unless outcome.success?
          raise InvalidConfig, YAML.dump(addon_class.addon_name => outcome.errors.deep_stringify_keys).delete_prefix("---\n")
        end

        prev_config = prev_configs[addon_class.addon_name]
        addon_class.apply_validate_configuration(prev_config, config)
      end

      with_disabled_addons do |addon_class, prev_config, config|
        addon_class.apply_validate_configuration(prev_config, config)
      end
    end

    def options
      {
        cpu_arch: @config.master_host.cpu_arch, # needs to be resolved *after* Phases::ValidateHost runs
        cluster_config: @config,
        cluster_context: @cluster_context
      }
    end

    def each(&block)
      with_enabled_addons do |addon_class, config_hash|
        config = addon_class.validate(config_hash)
        addon = addon_class.new(config, enabled: true, **options)
        addon.validate
        Retry.perform(yield_object: addon, logger: logger, &block)
      end

      with_disabled_addons do |addon_class, _, _|
        Retry.perform(yield_object: addon_class.new(nil, enabled: false, **options), logger: logger, &block)
      end
    end

    def with_enabled_addons
      configs.each do |name, config|
        klass = find_addon(name)
        if klass && (klass.enabled? || config['enabled'])
          yield(klass, config.merge('enabled' => true))
        end
      end
    end

    def with_disabled_addons
      addon_classes.each do |addon_class|
        prev_config = prev_configs[addon_class.addon_name]
        config = configs[addon_class.addon_name]
        next unless prev_config && prev_config['enabled'] && (config.nil? || !config['enabled'])

        yield(addon_class, prev_config, config)
      end
    end
  end
end
