Pharos.addon 'kontena-lens' do
  version '0.1.0-dev'
  license 'Kontena License'

  config_schema {
    required(:name).filled(:str?)
    required(:host).filled(:str?)
    required(:email).filled(:str?)
  }
end