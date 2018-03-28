# frozen_string_literal: true

module Kupo
  module Addons
    class IngressNginx < Kupo::Addon
      name 'ingress-nginx'
      version '0.11.0'
      license 'Apache License 2.0'

      struct {
        attribute :configmap, Kupo::Types::Hash
        attribute :node_selector, Kupo::Types::Hash
        attribute :default_backend, Kupo::Types::Hash
      }

      schema {
        optional(:configmap).filled(:hash?)
        optional(:node_selector).filled(:hash?)
        optional(:default_backend).schema do
          optional(:image).filled(:str?)
        end
      }

      DEFAULT_BACKEND_ARM64_IMAGE = 'docker.io/kontena/pharos-default-backend-arm64:0.0.2'.freeze
      DEFAULT_BACKEND_IMAGE = 'docker.io/kontena/pharos-default-backend:0.0.2'.freeze

      def image_name
        return config.default_backend[:image] if config.default_backend&.dig(:image)

        if host.cpu_arch.name == 'arm64'
          DEFAULT_BACKEND_ARM64_IMAGE
        else
          DEFAULT_BACKEND_IMAGE
        end
      end

      def install
        apply_stack(
          configmap: config.configmap || {},
          node_selector: config.node_selector,
          image: self.image_name
        )
      end
    end
  end
end
