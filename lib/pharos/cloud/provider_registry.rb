# frozen_string_literal: true

require "singleton"

module Pharos
  module Cloud
    class ProviderRegistry
      include Singleton

      def initialize
        @registry = {}
      end

      def provider(provider_name)
        (@registry[provider_name.to_sym] || Pharos::Cloud::Provider).new
      end

      def register_as(name, klass)
        @registry ||= {}
        @registry[name] = klass
      end
    end
  end
end
