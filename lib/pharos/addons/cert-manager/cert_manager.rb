# frozen_string_literal: true

Pharos.addon 'cert-manager' do
  version '0.2.3'
  license 'Apache License 2.0'

  issuer = custom_type {
    attribute :name, Pharos::Types::String
    attribute :server, Pharos::Types::String.optional
    attribute :email, Pharos::Types::String.default('https://acme-v01.api.letsencrypt.org/directory')
  }

  config {
    attribute :issuer, issuer
  }

  config_schema {
    required(:issuer).schema {
      required(:name).filled(:str?)
      required(:email).filled(:str?)
      optional(:server).filled(:str?)
    }
  }
end
