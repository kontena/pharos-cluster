# frozen_string_literal: true

module Pharos
  module Configuration
    class Cloud < Pharos::Configuration::Struct
      attribute :provider, Pharos::Types::String
      attribute :config, Pharos::Types::String

      INTREE_PROVIDERS = %w(aws azure cloudstack gce openstack ovirt photon vsphere)
      EXTERNAL_PROVIDERS = %w(hcloud)
      PROVIDERS = (INTREE_PROVIDERS + EXTERNAL_PROVIDERS).freeze

      # @return [Boolean]
      def intree_provider?
        INTREE_PROVIDERS.include?(provider)
      end

      # @return [Boolean]
      def outtree_provider?
        EXTERNAL_PROVIDERS.include?(provider)
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
