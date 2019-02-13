# frozen_string_literal: true

require 'dry-struct'

module Pharos
  module Phases
    class Component < Dry::Struct
      attribute :name, Pharos::Types::String
      attribute :version, Pharos::Types::String
      attribute :license, Pharos::Types::String
      attribute :os_release, Pharos::Configuration::OsRelease.optional.default(nil) # nil for generic components
      attribute :enabled, Pharos::Types::Instance(Proc).optional.default(nil)

      def enabled?(config)
        return false if !os_release.nil? && config.hosts.none? { |h| h.os_release.id == os_release.id && h.os_release.version == os_release.version }
        return true if enabled.nil?

        enabled.call(config)
      rescue
        require 'byebug'; byebug
      end

      def to_h
        super.tap { |s| s.delete(:enabled) }
      end
    end

    # List of registered components
    # @return [Set]
    def self.components
      @components ||= Set.new
    end

    def self.register_component(opts)
      components << Component.new(opts)
    end

    # @param config [Pharos::Config]
    # @return [Array<Pharos::Phases::Component>]
    def self.components_for_config(config)
      components.select { |c| c.enabled?(config) }
    end

    # Finds a component using arguments provided in a sym: value hash
    # @param [Hash] search_argument For example { name: 'kubernetes' }
    def self.find_component(search_arg)
      components.find do |component|
        search_arg.all? { |k, v| component.send(k) == v }
      end
    end
  end
end
