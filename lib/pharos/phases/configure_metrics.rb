# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMetrics < Pharos::Phase
      title "Configure metrics"

      HEAPSTER_VERSION = '1.5.1'

      register_component(
        name: 'heapster', version: HEAPSTER_VERSION, license: 'Apache License 2.0'
      )

      def call
        configure_heapster
      end

      def configure_heapster
        logger.info { "Provisioning client certificate for heapster ..." }
        cert_manager = Pharos::Kube::CertManager.new(@master, 'heapster-client-cert', namespace: 'kube-system')
        cert, _key = cert_manager.ensure_client_certificate(user: 'heapster')

        logger.info { "Configuring heapster ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'heapster',
          version: HEAPSTER_VERSION,
          image_repository: @config.image_repository,
          arch: @host.cpu_arch,
          client_cert: cert.to_pem
        )
      end
    end
  end
end
