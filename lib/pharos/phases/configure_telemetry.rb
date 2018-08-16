# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureTelemetry < Pharos::Phase
      title "Configure telemetry"

      def call
        logger.info { "Configuring telemetry service ..." }
        apply_stack(
          'telemetry',
          image_repository: @config.image_repository,
          arch: @host.cpu_arch
        )
      end
    end
  end
end
