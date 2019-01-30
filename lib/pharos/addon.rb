# frozen_string_literal: true

require 'hashdiff'
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

    # return class for use as superclass in Dry::Validation.Params
    Schema = Dry::Validation.Schema(build: false) do
      configure do
        def duration?(value)
          !Fugit::Duration.parse(value).nil?
        end

        def cron?(value)
          cron = Fugit::Cron.parse(value)

          return false if !cron
          return false if cron.seconds != [0]

          true
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

      required(:enabled).filled(:bool?)
    end

    class << self
      attr_accessor :addon_name
      attr_writer :addon_location

      # @return [String]
      def addon_location
        @addon_location || __dir__
      end

      def priority(priority = nil)
        if priority
          @priority = priority
        else
          @priority.to_i
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
        { name: addon_name, version: version, license: license }
      end

      def config_schema(&block)
        @schema = Dry::Validation.Params(Schema, &block)
      end

      def config(&block)
        @config ||= Class.new(Pharos::Addons::Struct, &block)
      end

      def config?
        !@config.nil?
      end

      def enable!
        @enabled = true
      end

      def enabled?
        !!@enabled
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

      def reset_host(&block)
        hooks[:reset_host] = block
      end

      def modify_cluster_config(&block)
        hooks[:modify_cluster_config] = block
      end

      def validate_configuration(&block)
        hooks[:validate_configuration] = block
      end

      # @param old_config [Hash,Pharos::Configuration]
      # @param new_config [Hash,Pharos::Configuration]
      # @return [nil]
      def apply_validate_configuration(old_config, new_config)
        hook = hooks[:validate_configuration]
        return unless hook

        case hook.arity
        when 1
          hook.call(new_config)
        when 2
          hook.call(old_config, new_config)
        when 3
          HashDiff.diff(old_config, new_config).each do |changeset|
            case changeset.first
            when '-'
              hook.call(changeset[1], changeset[2], nil)
            when '+'
              hook.call(changeset[1], nil, changeset[2])
            when '~'
              hook.call(changeset[1], changeset[2], changeset[3])
            end
          end
        end
        nil
      end

      def validation
        Dry::Validation.Params(Schema) { yield }
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

    attr_reader :config, :cpu_arch, :cluster_config, :kube_client

    # @param config [Hash,Dry::Validation::Result]
    # @param enabled [Boolean]
    # @param kube_client [K8s::Client]
    # @param cpu_arch [String, NilClass]
    # @param cluster_config [Pharos::Config, NilClass]
    def initialize(config = nil, enabled: true, kube_client:, cpu_arch:, cluster_config:)
      @config = self.class.config? ? self.class.config.new(config) : RecursiveOpenStruct.new(Hash(config))
      @enabled = enabled
      @kube_client = kube_client
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

    # @param host [Pharos::Configuration::Host]
    def apply_reset_host(host)
      instance_exec(host, &hooks[:reset_host]) if hooks[:reset_host]
    end

    def apply_modify_cluster_config
      instance_eval(&hooks[:modify_cluster_config]) if hooks[:modify_cluster_config]
    end

    def post_install_message(msg = nil)
      if msg
        @post_install_message = msg
      else
        @post_install_message
      end
    end

    # @param vars [Hash]
    # @return [Pharos::Kube::Stack]
    def kube_stack(**vars)
      Pharos::Kube.stack(
        name,
        File.join(self.class.addon_location, 'resources'),
        name: name,
        version: self.class.version,
        config: config,
        arch: cpu_arch,
        image_repository: cluster_config.image_repository,
        **vars
      )
    end

    # @param vars [Hash]
    # @return [Array<K8s::Resource>]
    def apply_resources(**vars)
      kube_stack(vars).apply(kube_client)
    end

    # @return [Array<K8s::Resource>]
    def delete_resources
      Pharos::Kube::Stack.new(name).delete(kube_client)
    end

    def validate; end
  end
end
