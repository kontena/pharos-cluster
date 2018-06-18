# frozen_string_literal: true

Pharos.addon 'host-upgrades' do
  version '0.1.0'
  license 'Apache License 2.0'

  config {
    attribute :schedule, Pharos::Types::String
    attribute :schedule_window, Pharos::Types::String
    attribute :reboot, Pharos::Types::Bool.default(false)
    attribute :drain, Pharos::Types::Bool.default(true)
  }

  config_schema {
    configure do
      SCHEDULE_RE = %r(^([*?]|[A-Z0-9/,-]+)(\s+([*?]|[A-Z0-9/,-]+)){5}|@\w+$)
      DURATION_RE = /^(\d+(\.\d+)?(ns|us|ms|s|m|h|))+$/

      def schedule?(value)
        !!SCHEDULE_RE.match?(value)
      end

      def duration?(value)
        !!DURATION_RE.match?(value)
      end

      def self.messages
        super.merge(
          en: { errors: {
            schedule?: 'is not a valid cron schedule: https://github.com/kontena/pharos-host-upgrades#--schedule',
            duration?: 'is not a valid Duration: https://golang.org/pkg/time/#ParseDuration'
          } }
        )
      end
    end

    required(:schedule).filled(:str?, :schedule?)
    optional(:schedule_window).filled(:str?, :duration?)
    optional(:reboot).filled(:bool?)
    optional(:drain).filled(:bool?)
  }

  install {
    apply_resources(
      schedule: config.schedule,
      schedule_window: config.schedule_window,
      reboot: config.reboot,
      drain: config.reboot && config.drain,
      journal: false, # disabled due to https://github.com/kontena/pharos-host-upgrades/issues/15
    )
  }
end
