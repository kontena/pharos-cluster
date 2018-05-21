# frozen_string_literal: true

require 'dry-validation'
require_relative 'addons/struct'
require_relative 'logging'

module Pharos
  # @param name [String]
  # @return [Pharos::Addon]
  def self.addon(name, &block)
    klass = Class.new(Pharos::Addon, &block).tap do |addon|
      addon.addon_location = block.source_location.first
    end

    # Magic to create Pharos::Addons::IngressNginx etc so that specs still work
    Pharos::Addons.const_set(name.split(/[-_ ]/).map(&:capitalize).join, klass)
    Pharos::AddonManager.addons << klass
    klass
  end

  class Addon
    include Pharos::Logging

    class Schema < Dry::Validation::Schema
      configure do
        def duration?(value)
          !Fugit::Duration.parse(value).nil?
        end

        def self.messages
          super.merge(
            en: { errors: { duration?: 'is not valid duration' } }
          )
        end
      end

      define! do
        required(:enabled).filled(:bool?)
      end
    end

    class << self
      attr_writer :addon_location

      # @return [String]
      def addon_location
        @addon_location || __dir__
      end

      def name(name = nil)
        if name
          @name = name
        else
          @name
        end
      end

      def version(version = nil)
        if version
          @version = version
        else
          @version
        end
      end

      def license(license = nil)
        if license
          @license = license
        else
          @license
        end
      end

      def to_h
        { name: name, version: version, license: license }
      end

      def config_schema(&block)
        @schema = Dry::Validation.Form(Schema, &block)
      end

      def config(&block)
        @config ||= Class.new(Pharos::Addons::Struct, &block)
      end

      def config?
        !@config.nil?
      end

      def custom_type(&block)
        Class.new(Pharos::Addons::Struct, &block)
      end

      # @return [Hash]
      def hooks
        @hooks ||= {}
      end

      def install(&block)
        hooks[:install] = block
      end

      def uninstall(&block)
        hooks[:uninstall] = block
      end

      def validation
        Dry::Validation.Form(Schema) { yield }
      end

      # @param config [Hash]
      def validate(config)
        if @schema
          @schema.call(config)
        else
          validation {}.call(config)
        end
      end

      def descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end
    end

    attr_reader :config, :cpu_arch, :cluster_config, :master

    # @param config [Hash]
    # @param enabled [Boolean]
    # @param master [Pharos::Configuration::Host,NilClass]
    # @param cpu_arch [String, NilClass]
    # @param cluster_config [Pharos::Config, NilClass]
    def initialize(config = nil, enabled: true, master:, cpu_arch:, cluster_config:)
      @config = self.class.config? ? self.class.config.new(config) : RecursiveOpenStruct.new(config)
      @enabled = enabled
      @master = master
      @cpu_arch = cpu_arch
      @cluster_config = cluster_config
    end

    def name
      self.class.name
    end

    def duration
      Fugit::Duration
    end

    def enabled?
      @enabled
    end

    def apply
      if enabled?
        apply_install
      else
        apply_uninstall
      end
    end

    def hooks
      self.class.hooks
    end

    def apply_install
      if hooks[:install]
        self.instance_eval(&hooks[:install])
      else
        install
      end
    end

    def apply_uninstall
      if hooks[:uninstall]
        self.instance_eval(&hooks[:uninstall])
      else
        uninstall
      end
    end

    # @return [Pharos::Kube::Session]
    def kube_session
      Pharos::Kube.session(master.api_address)
    end

    # @return [Kubeclient]
    def kube_client
      kube_session.resource_client
    end

    # @param vars [Hash]
    # @return [Pharos::Kube::Stack]
    def kube_stack(vars = {})
      Pharos::Kube::Stack.new(
        kube_session, self.class.name, File.join(self.class.addon_location, 'resources'),
        vars.merge(
          name: self.class.name,
          version: self.class.version,
          config: config,
          arch: cpu_arch
        )
      )
    end

    def apply_stack(vars = {})
      kube_stack(vars).apply
    end
    alias_method :install, :apply_stack

    def prune_stack
      kube_stack.prune('-')
    end
    alias_method :uninstall, :prune_stack

    def validate; end
  end
end
