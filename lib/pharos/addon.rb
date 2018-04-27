# frozen_string_literal: true

require 'dry-validation'
require_relative 'addons/struct'

module Pharos
  class Addon
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

    def self.schema(&block)
      @schema = Dry::Validation.Form(Schema, &block)
    end

    def self.struct(&block)
      @struct ||= Class.new(Pharos::Addons::Struct, &block)
    end

    def self.validation
      Dry::Validation.Form(Schema) { yield }
    end

    def self.validate(config)
      if @schema
        @schema.call(config)
      else
        validation {}.call(config)
      end
    end

    def self.descendants
      ObjectSpace.each_object(Class).select { |klass| klass < self }
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

    def apply_stack(vars = {})
      Pharos::Kube.apply_stack(
        @master.address, self.class.name,
        vars.merge(
          name: self.class.name,
          version: self.class.version,
          config: @config,
          arch: @cpu_arch
        )
      )
    end

    def prune_stack
      Pharos::Kube.prune_stack(@master.address, self.class.name, '-')
    end
  end
end
