# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMetrics < Pharos::Phase
      title "Configure metrics"

      register_component(
        name: 'heapster', version: '1.5.1', license: 'Apache License 2.0'
      )

      def call
        configure_heapster
      end

      def configure_heapster
        info "Provisioning client certificate for heapster ..."
        cert_manager = Pharos::Kube::CertManager.new(@master, 'heapster-client-cert', namespace: 'kube-system')
        cert, _key = cert_manager.ensure_client_certificate(user: 'heapster')

        info "Configuring heapster ..."
        Pharos::Kube.apply_stack(
          @master.api_address, 'heapster',
          version: '1.5.1',
          arch: @host.cpu_arch,
          client_cert: cert.to_pem
        )
      end
    end
  end
end
