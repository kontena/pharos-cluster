# frozen_string_literal: true

require_relative 'addon'
require_relative 'phases/logging'

module Pharos
  class AddonManager
    include Pharos::Phases::Logging

    class InvalidConfig < Pharos::Error; end
    class UnknownAddon < Pharos::Error; end

    # @param dirs [Array<String>]
    def initialize(dirs)
      load_addons(dirs)
    end

    # @param configs [Hash]
    def validate(configs)
      with_enabled_addons(configs) do |addon_class, config|
        outcome = addon_class.validate(config)
        unless outcome.success?
          raise InvalidConfig, outcome.errors
        end
      end
    end

    # @param host [Pharos::Configuration::Host]
    # @param configs [Hash]
    def apply(host, configs)
      with_enabled_addons(configs) do |addon_class, config|
        logger.info { "Applying addon #{addon_class.name} ..." }
        schema = addon_class.validate(config)
        addon = addon_class.new(host, schema)
        addon.install
      end

      with_disabled_addons(configs) do |addon_class, config|
        addon = addon_class.new(host, config)
        addon.uninstall
      end
    end

    # @param configs [Hash
    def with_enabled_addons(configs)
      configs.each do |name, config|
        klass = addon_classes.find { |a| a.name == name }
        if klass && config["enabled"]
          yield(klass, config)
        elsif klass.nil?
          raise UnknownAddon, "unknown addon: #{name}"
        end
      end
    end

    # @param configs [Hash
    def with_disabled_addons(configs)
      addon_classes.each do |addon_class|
        config = configs[addon_class.name]
        if config.nil? || !config["enabled"]
          yield(addon_class)
        end
      end
    end

    # @return [Array<Pharos::Addon>]
    def addon_classes
      @addon_classes ||= Pharos::Addon.descendants
    end

    # @param dirs [Array<String>]
    def load_addons(dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end
  end
end
