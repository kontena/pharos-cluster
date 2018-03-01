module Kupo
  module Addons
    class IngressNginx < Kupo::Addon

      name 'ingress-nginx'
      version '0.11.0'
      license 'Apache License 2.0'

      struct { |s|
        s.attribute :options, Kupo::Types::Hash
      }
      schema {
        optional(:options).filled(:hash?)
      }

    end
  end
end