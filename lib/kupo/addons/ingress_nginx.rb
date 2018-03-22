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
        attribute :image, Kupo::Types::String
      }

      schema {
        optional(:configmap).filled(:hash?)
        optional(:node_selector).filled(:hash?)
        optional(:image).filled(:str?)
      }

      def image_name
        return config.image if config.image
        if host.cpu_arch.name == 'arm64'
          'kontena/pharos-default-backend-arm64:0.0.2'
        else
          'kontena/pharos-default-backend:0.0.2'
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
