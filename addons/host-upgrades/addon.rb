# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.0.0'
  license 'Apache License 2.0'

  config {
    attribute :image_tag, Pharos::Types::String.default("edge")
    attribute :schedule, Pharos::Types::String
    attribute :schedule_window, Pharos::Types::String
    attribute :reboot, Pharos::Types::Bool.default(false)
    attribute :drain, Pharos::Types::Bool.default(true)
  }

  config_schema {
    optional(:image_tag).filled(:str?)
    required(:schedule).filled(:str?)
    optional(:schedule_window).filled(:str?)
    optional(:reboot).filled(:bool?)
    optional(:drain).filled(:bool?)
  }

  install {
    apply_resources(
      image_tag: config.image_tag,
      schedule: config.schedule,
      schedule_window: config.schedule_window,
      reboot: config.reboot,
      drain: config.reboot && config.drain,
      journal: false, # disabled due to https://github.com/kontena/pharos-host-upgrades/issues/15
    )
  }
end
