# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.3.1'
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

  # @return [String]
  def schedule
    cron = Fugit::Cron.parse(config.schedule)

    cron.to_cron_s
  end

  # @return [String]
  def schedule_window
    return '0' if !config.schedule_window

    s = Fugit::Duration.parse(config.schedule_window).to_sec

    "#{s}s"
  end

  install {
    apply_resources(
      schedule: schedule,
      schedule_window: schedule_window, # only supports h, m, s; not D, M, Y
      reboot: config.reboot,
      drain: config.reboot && config.drain,
      journal: false # disabled due to https://github.com/kontena/pharos-host-upgrades/issues/15
    )
  }
end
