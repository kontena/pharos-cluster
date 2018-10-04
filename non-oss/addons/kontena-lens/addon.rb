# frozen_string_literal: true

Pharos.addon 'kontena-lens' do
  version '0.1.0-dev'
  license 'Kontena License'

  config_schema {
    optional(:name).filled(:str?)
    optional(:host).filled(:str?)
    optional(:email).filled(:str?)
  }
end
