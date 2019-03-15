# frozen_string_literal: true

module Pharos
  module Configuration
    class Cloud < Pharos::Configuration::Struct
      attribute :provider, Pharos::Types::String
      attribute :config, Pharos::Types::String

      INTREE_PROVIDERS = %w( aws azure cloudstack gce openstack ovirt photon vsphere ).freeze

      # @return [Array<String>]
      def self.external_providers
        Pharos::Cloud::ProviderRegistry.instance.providers.keys.map { |name| name.to_s }
      end

      # @return [Array<String>]
      def self.providers
        INTREE_PROVIDERS + external_providers
      end

      # @return [Boolean]
      def intree_provider?
        INTREE_PROVIDERS.include?(provider)
      end

      # @return [Boolean]
      def outtree_provider?
        self.class.external_providers.include?(provider)
      end

      # @return [String]
      def resolve_provider
        return provider if intree_provider?

        'external'
      end

      # @return [Pharos::Cloud::Provider]
      def cloud_provider
        Pharos::Cloud::ProviderRegistry.instance.provider(provider)
      end
    end
  end
end
