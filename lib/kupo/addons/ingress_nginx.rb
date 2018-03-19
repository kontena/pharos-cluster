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

      def install
        apply_stack(
          configmap: config.configmap || {},
          node_selector: config.node_selector,
          image: config.image
        )
      end
    end
  end
end
