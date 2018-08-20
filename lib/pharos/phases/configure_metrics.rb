# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMetrics < Pharos::Phase
      title "Configure metrics"

      METRICS_SERVER_VERSION = '0.2.1'

      register_component(
        name: 'metrics-server', version: METRICS_SERVER_VERSION, license: 'Apache License 2.0'
      )

      def call
        configure_metrics_server
      end

      def configure_metrics_server
        logger.info { "Configuring metrics server ..." }
        apply_stack(
          'metrics-server',
          version: METRICS_SERVER_VERSION,
          image_repository: @config.image_repository,
          arch: @host.cpu_arch
        )
      end
    end
  end
end
