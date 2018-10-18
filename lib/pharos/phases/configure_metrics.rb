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
        retries = 0
        begin
          apply_stack(
            'metrics-server',
            version: METRICS_SERVER_VERSION,
            image_repository: @config.image_repository,
            arch: @host.cpu_arch,
            worker_count: @config.worker_hosts.size
          )
        rescue K8s::Error::NotFound, K8s::Error::ServiceUnavailable => exc
          # retry until kubernetes api reports that metrics-server is available
          raise if retries >= 10

          logger.debug { "#{exc.class.name}: #{exc.message}" }
          sleep 2**retries
          retries += 1
          retry
        end
      end
    end
  end
end
