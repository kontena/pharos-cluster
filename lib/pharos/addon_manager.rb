# frozen_string_literal: true

require_relative 'addon'

module Pharos
  class AddonManager
    class InvalidConfig < Pharos::Error; end
    class UnknownAddon < Pharos::Error; end

    # @param dirs [Array<String>]
    def self.load_addons(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end

    # @param config [Pharos::Configuration]
    # @param cluster_context [Hash]
    def initialize(config, cluster_context)
      @config = config
      @cluster_context = cluster_context
    end

    def configs
      @config.addons
    end

    def prev_configs
      if config = @cluster_context['previous-config']
        config.addons
      else
        {}
      end
    end

    # @return [Array<Pharos::Addon>]
    def addon_classes
      @addon_classes ||= Pharos::Addon.descendants
    end

    def validate
      with_enabled_addons do |addon_class, config|
        outcome = addon_class.validate(config)
        unless outcome.success?
          raise InvalidConfig, outcome.errors
        end
      end
    end

    def options
      {
        master: @config.master_host,
        cpu_arch: @config.master_host.cpu_arch, # needs to be resolved *after* Phases::ValidateHost runs
        cluster_config: @config
      }
    end

    def each
      with_enabled_addons do |addon_class, config_hash|
        config = addon_class.validate(config_hash)
        addon = addon_class.new(config, enabled: true, **options)
        addon.validate
        yield addon
      end

      with_disabled_addons do |addon_class|
        yield addon_class.new(nil, enabled: false, **options)
      end
    end

    def with_enabled_addons
      configs.each do |name, config|
        klass = addon_classes.find { |a| a.name == name }
        if klass && config["enabled"]
          yield(klass, config)
        elsif klass.nil?
          raise UnknownAddon, "unknown addon: #{name}"
        end
      end
    end

    def with_disabled_addons
      addon_classes.select { |addon_class|
        prev_config = prev_configs[addon_class.name]
        config = configs[addon_class.name]
        prev_config && prev_config["enabled"] && (config.nil? || !config["enabled"])
      }.each do |addon_class|
        yield(addon_class)
      end
    end
  end
end
