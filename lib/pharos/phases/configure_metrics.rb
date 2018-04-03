# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureMetrics < Base
      register_component(
        Pharos::Phases::Component.new(
          name: 'metrics-server', version: '0.2.1', license: 'Apache License 2.0'
        )
      )

      register_component(
        Pharos::Phases::Component.new(
          name: 'heapster', version: '1.5.1', license: 'Apache License 2.0'
        )
      )

      # @param master [Pharos::Configuration::Host]
      def initialize(master)
        @master = master
      end

      def call
        configure_metrics_server
        configure_heapster
      end

      def configure_metrics_server
        logger.info { "Provisioning client certificate for metrics-server ..." }
        cert_manager = Pharos::Kube::CertManager.new(@master, 'metrics-server-client-cert', namespace: 'kube-system')
        cert, _key = cert_manager.ensure_client_certificate(user: 'metrics-server')

        logger.info { "Configuring metrics-server ..." }
        Pharos::Kube.apply_stack(@master.address, 'metrics-server',
                               version: '0.2.1',
                               arch: @master.cpu_arch,
                               client_cert: cert.to_pem)
      end

      def configure_heapster
        logger.info { "Provisioning client certificate for heapster ..." }
        cert_manager = Pharos::Kube::CertManager.new(@master, 'heapster-client-cert', namespace: 'kube-system')
        cert, _key = cert_manager.ensure_client_certificate(user: 'heapster')

        logger.info { "Configuring heapster ..." }
        Pharos::Kube.apply_stack(@master.address, 'heapster',
                               version: '1.5.1',
                               arch: @master.cpu_arch,
                               client_cert: cert.to_pem)
      end
    end
  end
end
