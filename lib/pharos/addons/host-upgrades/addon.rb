# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.1.0'
  license 'Apache License 2.0'

  config {
    attribute :interval, Pharos::Types::String
  }

  config_schema {
    required(:interval).filled(:str?, :duration?)
  }

  install {
    install(
      interval: duration.parse(config.interval).to_sec
    )
  }
end
