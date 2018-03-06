module Kupo
  module Addons
    class IngressNginx < Kupo::Addon

      name 'ingress-nginx'
      version '0.11.0'
      license 'Apache License 2.0'

      struct {
        attribute :configmap, Kupo::Types::Hash
        attribute :node_selector, Kupo::Types::Hash
      }

      schema {
        optional(:configmap).filled(:hash?)
        optional(:node_selector).filled(:hash?)
      }

      def install
        apply_stack({
          configmap: config.configmap || {}
        })
      end
    end
  end
end
