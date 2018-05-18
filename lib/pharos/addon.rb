# frozen_string_literal: true

require 'dry-validation'
require_relative 'logging'

module Pharos
  class Addon
    include Pharos::Logging

    # Load addon classes from filesystem path
    #
    # @param path [String] path to dir containing */*.rb addon dirs
    # @return [Array<Class<Kontena::Pharos::Addon>>]
    def self.loads(path)
      paths = Dir.glob("#{path}/*")
      paths.map{|path| self.load(path)}
    end

    # Load addon class from local filesystem directory
    #
    # @param path [String]
    # @return [Class<Kontena::Pharos::Addon>]
    def self.load(path)
      name = File.basename(path, '/')

      addon_class = Class.new(self) do |cls|
        cls.path = path
        cls.name = name

        Dir.glob("#{path}/*.rb") do |filepath|
          File.open(filepath, "r") do |file|
            cls.class_eval(file.read, file.path)
          end
        end
      end

      # TODO: only needed for specs? Pharos::Addons.const_set(name.split(/[-_ ]/).map(&:capitalize).join, addon_class)

      addon_class
    end

    class Struct < Dry::Struct
      constructor_type :schema

      attribute :enabled, Pharos::Types::Strict::Bool
    end

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

    def self.path=(path)
      @path = path
    end

    def self.path
      @path
    end

    def self.name=(name)
      @name = name
    end

    def self.name(name = nil)
      if name
        @name = name
      else
        @name
      end
    end

    def self.version(version = nil)
      if version
        @version = version
      else
        @version
      end
    end

    def self.license(license = nil)
      if license
        @license = license
      else
        @license
      end
    end

    def self.to_h
      { name: name, version: version, license: license }
    end

    def self.schema(&block)
      if block
        @schema = Dry::Validation.Form(Schema, &block)
      else
        @schema ||= Dry::Validation.Form(Schema)
      end
    end

    def self.struct(&block)
      if block
        @struct = Class.new(Pharos::Addon::Struct, &block)
      else
        @struct ||= Class.new(Pharos::Addon::Struct)
      end
    end

    # @return [Dry::Validation::Result]
    def self.validate(config)
      schema.call(config)
    end

    attr_reader :config, :cpu_arch, :cluster_config

    def initialize(config = nil, enabled: true, master:, cpu_arch:, cluster_config:)
      @config = self.class.struct.new(config)
      @enabled = enabled
      @master = master
      @cpu_arch = cpu_arch
      @cluster_config = cluster_config
    end

    def name
      self.class.name
    end

    # @return [String]
    def path(*parts)
      File.join(self.class.path, *parts)
    end

    def duration
      Fugit::Duration
    end

    def enabled?
      @enabled
    end

    def apply
      if enabled?
        install
      else
        uninstall
      end
    end

    def install
      apply_stack
    end

    def uninstall
      prune_stack
    end

    # @return [Pharos::Kube::Session]
    def kube_session
      Pharos::Kube.session(@master.api_address)
    end

    def kube_stack(vars = {})
      Pharos::Kube::Stack.new(
        kube_session, self.class.name, self.path('resources'),
        vars.merge(
          name: self.class.name,
          version: self.class.version,
          config: @config,
          arch: @cpu_arch
        )
      )
    end

    def apply_stack(vars = {})
      kube_stack(vars).apply
    end

    def prune_stack
      kube_stack.prune('-')
    end

    def validate; end
  end
end
