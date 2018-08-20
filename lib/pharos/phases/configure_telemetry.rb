# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureTelemetry < Pharos::Phase
      title "Configure telemetry"

      def call
        if @config.telemetry.enabled
          logger.info { "Configuring telemetry service ..." }
          apply_stack(
            'telemetry',
            image_repository: @config.image_repository,
            arch: @host.cpu_arch
          )
        else
          logger.info { "Disabling telemetry service ..." }
          delete_stack('telemetry')
        end
      end
    end
  end
end
