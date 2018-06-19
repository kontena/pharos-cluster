# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.2.0'
  license 'Apache License 2.0'

  config {
    attribute :schedule, Pharos::Types::String
    attribute :schedule_window, Pharos::Types::String
    attribute :reboot, Pharos::Types::Bool.default(false)
    attribute :drain, Pharos::Types::Bool.default(true)
  }

  config_schema {
    required(:schedule).filled(:str?, :cron?)
    optional(:schedule_window).filled(:str?, :duration?)
    optional(:reboot).filled(:bool?)
    optional(:drain).filled(:bool?)
  }

  install {
    apply_resources(
      schedule: config.schedule,
      schedule_window: config.schedule_window, # only supports h, m, s
      reboot: config.reboot,
      drain: config.reboot && config.drain,
      journal: false, # disabled due to https://github.com/kontena/pharos-host-upgrades/issues/15
    )
  }
end
