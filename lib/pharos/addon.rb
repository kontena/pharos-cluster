# frozen_string_literal: true

require 'dry-validation'
require 'fugit'

require_relative 'addons/struct'
require_relative 'logging'

module Pharos
  # @param name [String]
  # @return [Pharos::Addon]
  def self.addon(name, &block)
    klass = Class.new(Pharos::Addon, &block).tap do |addon|
      addon.addon_location = File.dirname(block.source_location.first)
      addon.addon_name = name
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

        def cron?(value)
          !Fugit::Cron.parse(value).nil?
        end

        def self.messages
          super.merge(
            en: { errors: {
              duration?: 'is not valid duration',
              cron?: 'is not a valid crontab'
            } }
          )
        end
      end

      define! do
        required(:enabled).filled(:bool?)
      end
    end

    class << self
      attr_accessor :addon_name
      attr_writer :addon_location

      # @return [String]
      def addon_location
        @addon_location || __dir__
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
        { name: addon_name, version: version, license: license }
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
    end

    attr_reader :config, :cpu_arch, :cluster_config, :master

    # @param config [Hash,Dry::Validation::Result]
    # @param enabled [Boolean]
    # @param master [Pharos::Configuration::Host,NilClass]
    # @param cpu_arch [String, NilClass]
    # @param cluster_config [Pharos::Config, NilClass]
    def initialize(config = nil, enabled: true, master:, cpu_arch:, cluster_config:)
      @config = self.class.config? ? self.class.config.new(config) : RecursiveOpenStruct.new(Hash(config))
      @enabled = enabled
      @master = master
      @cpu_arch = cpu_arch
      @cluster_config = cluster_config
    end

    def name
      self.class.addon_name
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
        instance_eval(&hooks[:install])
      else
        apply_resources
      end
    end

    def apply_uninstall
      if hooks[:uninstall]
        instance_eval(&hooks[:uninstall])
      else
        delete_resources
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
        kube_session, name, File.join(self.class.addon_location, 'resources'),
        vars.merge(
          name: name,
          version: self.class.version,
          config: config,
          arch: cpu_arch
        )
      )
    end

    # @param vars [Hash]
    # @return [Array<Kubeclient::Resource>]
    def apply_resources(vars = {})
      kube_stack(vars).apply
    end

    # @return [Array<Kubeclient::Resource>]
    def delete_resources
      kube_stack.prune('-')
    end

    def validate; end
  end
end
