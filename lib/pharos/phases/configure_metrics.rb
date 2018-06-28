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
        remove_heapster
      end

      def configure_metrics_server
        logger.info { "Configuring metrics server ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'metrics-server',
          version: METRICS_SERVER_VERSION,
          image_repository: @config.image_repository,
          arch: @host.cpu_arch
        )
      end

      # TODO: remove this in 1.3
      def remove_heapster
        logger.debug { "Removing heapster ..." }
        Pharos::Kube.remove_stack(
          @master.api_address, 'heapster'
        )
      end
    end
  end
end
