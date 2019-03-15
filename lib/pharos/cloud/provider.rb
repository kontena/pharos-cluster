# frozen_string_literal: true

require_relative "provider_registry"

module Pharos
  module Cloud
    class Provider
      # @param name [String]
      def self.register_as(name)
        Pharos::Cloud::ProviderRegistry.instance.register_as(name, self)
      end

      # @return [Hash]
      def feature_gates
        {}
      end

      # @return [Boolean]
      def csi?
        false
      end
    end
  end
end
