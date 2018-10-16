# frozen_string_literal: true

Pharos.addon 'license-manager' do
  version Pharos::VERSION
  license 'Kontena License'
  enable!

  config {
    attribute :key, Pharos::Types::String.default('EVALUATION')
  }

  config_schema {
    optional(:key).filled(:str?)
  }
end
