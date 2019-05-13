# frozen_string_literal: true

require "singleton"

module Pharos
  module Cloud
    class ProviderRegistry
      include Singleton

      def initialize
        @registry = {}
      end

      # @param provider_name [String,Symbol]
      # @return [Pharos::Cloud::Provider]
      def provider(provider_name)
        (@registry[provider_name.to_sym] || Pharos::Cloud::Provider).new
      end

      # @param name [String]
      # @param klass [Class]
      def register_as(name, klass)
        @registry ||= {}
        @registry[name] = klass
      end

      # @return [Hash{Symbol => Pharos::Cloud::Provider}]
      def providers
        @registry
      end
    end
  end
end
