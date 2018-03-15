# frozen_string_literal: true

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

      struct do
        attribute :issuer, Issuer
      end

      schema do
        required(:issuer).schema do
          required(:name).filled(:str?)
          required(:email).filled(:str?)
          optional(:server).filled(:str?)
        end
      end
    end
  end
end
