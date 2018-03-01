require 'dry-validation'
require_relative 'addons/struct'
require_relative 'phases/logging'

module Shokunin
  class Addon
    include Shokunin::Phases::Logging

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

    def self.struct
      @struct ||= Class.new(Shokunin::Addons::Struct) do
        yield(self) if block_given?
      end
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

    attr_reader :host, :config

    def initialize(host, config)
      @host = host
      @config = self.class.struct.new(config)
    end

    def duration
      Fugit::Duration
    end

    def install
      apply_stack
    end

    def uninstall
      prune_stack
    end

    def apply_stack(vars = {})
      Shokunin::Kube.apply_stack(host.address, self.class.name, vars)
    end

    def prune_stack
      Shokunin::Kube.prune_stack(host.address, self.class.name, '-')
    end
  end
end