# frozen_string_literal: true

version '0.2.3'
license 'Apache License 2.0'

class Issuer < Dry::Struct
  attribute :name, Pharos::Types::String
  attribute :server, Pharos::Types::String.optional
  attribute :email, Pharos::Types::String.default('https://acme-v01.api.letsencrypt.org/directory')
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
