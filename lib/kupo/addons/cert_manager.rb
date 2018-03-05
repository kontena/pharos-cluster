module Kupo
  module Addons
    class CertManager < Kupo::Addon

      name 'cert-manager'
      version '0.2.3'
      license 'Apache License 2.0'

      class Issuer < Kupo::Addons::Struct
        attribute :name, Kupo::Types::String
        attribute :server, Kupo::Types::String
        attribute :email, Kupo::Types::String.default('https://acme-v01.api.letsencrypt.org/directory')
      end

      struct {
        attribute :issuer, Issuer
      }

      schema {
        required(:issuer).schema {
          required(:name).filled(:str?)
          required(:email).filled(:str?)
          optional(:server).filled(:str?)
        }
      }
    end
  end
end