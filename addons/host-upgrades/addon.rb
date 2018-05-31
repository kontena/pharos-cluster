# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.0.0'
  license 'Apache License 2.0'

  IMAGE = 'quay.io/kontena/pharos-host-upgrades'

  config {
    attribute :image_tag, Pharos::Types::String.default("edge")
    attribute :schedule, Pharos::Types::String.default("0 0 0 * * *")
    attribute :schedule_window, Pharos::Types::String.default("2h")
    attribute :reboot, Pharos::Types::Bool.default(false)
    attribute :drain, Pharos::Types::Bool.default(true)
  }

  install {
    apply_resources(
      image: "#{IMAGE}:#{config.image_tag}",
      schedule: config.schedule,
      schedule_window: config.schedule_window,
      reboot: config.reboot,
      drain: config.drain,
      journal: false, # disabled ue to https://github.com/kontena/pharos-host-upgrades/issues/15
    )
  }
end
