# frozen_string_literal: true

Pharos.addon('do-csi') do
  version '1.0.0'
  license 'Apache 2.0'

  config_schema do
    optional(:token).filled(:str?)
  end
end
