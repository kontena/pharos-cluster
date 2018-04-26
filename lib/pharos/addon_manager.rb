# frozen_string_literal: true

require_relative 'addon'
require_relative 'logging'

module Pharos
  class AddonManager
    include Pharos::Logging

    class InvalidConfig < Pharos::Error; end
    class UnknownAddon < Pharos::Error; end

    # @param dirs [Array<String>]
    def self.load_addons(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end

    # @param config [Pharos::Configuration]
    def initialize(config)
      @config = config
    end

    def configs
      @config.addons
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

        yield addon_class.new(config, enabled: true, master: @master, **options)
      end

      with_disabled_addons do |addon_class|
        yield addon_class.new(nil, enabled: false, master: @master, **options)
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
      addon_classes.each do |addon_class|
        config = configs[addon_class.name]
        if config.nil? || !config["enabled"]
          yield(addon_class)
        end
      end
    end
  end
end
