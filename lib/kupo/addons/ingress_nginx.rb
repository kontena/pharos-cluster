# frozen_string_literal: true

module Kupo
  module Addons
    class IngressNginx < Kupo::Addon
      name 'ingress-nginx'
      version '0.11.0'
      license 'Apache License 2.0'

      struct do
        attribute :configmap, Kupo::Types::Hash
        attribute :node_selector, Kupo::Types::Hash
      end

      schema do
        optional(:configmap).filled(:hash?)
        optional(:node_selector).filled(:hash?)
      end

      def install
        apply_stack(
          configmap: config.configmap || {},
          node_selector: config.node_selector
        )
      end
    end
  end
end
