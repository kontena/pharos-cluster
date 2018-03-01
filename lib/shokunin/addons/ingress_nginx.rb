module Shokunin
  module Addons
    class IngressNginx < Shokunin::Addon

      name 'ingress-nginx'
      version '0.11.0'
      license 'Apache License 2.0'

      struct { |s|
        s.attribute :options, Shokunin::Types::Hash
      }
      schema {
        optional(:options).filled(:hash?)
      }

    end
  end
end