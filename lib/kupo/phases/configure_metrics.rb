# frozen_string_literal: true

require_relative 'base'

module Kupo::Phases
  class ConfigureMetrics < Base
    register_component(Kupo::Phases::Component.new(
                         name: 'metrics-server', version: '0.2.1', license: 'Apache License 2.0'
    ))

    register_component(Kupo::Phases::Component.new(
                         name: 'heapster', version: '1.5.1', license: 'Apache License 2.0'
    ))

    class CertManager
      # @param host [Kupo::Configuration::Host]
      # @param name [String]
      # @param namespace [String]
      def initialize(host, name, namespace: )
        @host = host
        @name = name
        @namespace = namespace
      end

      # @return [OpenSSL::PKey]
      def generate_private_key()
        OpenSSL::PKey::RSA.generate(2048)
      end

      # @yieldreturn [Hash] generated secret data
      # @return [Kubeclient::Resource]
      def ensure_secret
        resource = Kubeclient::Resource.new(
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: {
            namespace: @namespace,
            name: @name,
          }
        )

        begin
          resource = Kupo::Kube.get_resource(@host.address, resource)
        rescue Kubeclient::ResourceNotFoundError
          resource[:data] = yield
          resource = Kupo::Kube.create_resource(@host.address, resource)
        end

        resource
      end

      # @param key [OpenSSL::PKey]
      # @param subject_cn [String]
      # @return [Kubeclient::Resource]
      def ensure_csr(key, subject_cn: , usages: )
        request = OpenSSL::X509::Request.new
        request.version = 0
        request.subject = OpenSSL::X509::Name.new([
          ['CN', subject_cn, OpenSSL::ASN1::UTF8STRING],
        ])
        request.public_key = key.public_key
        request.sign(key, OpenSSL::Digest::SHA256.new)

        Kupo::Kube.apply_resource(@host.address, Kubeclient::Resource.new(
          apiVersion: 'certificates.k8s.io/v1beta1',
          kind: 'CertificateSigningRequest',
          metadata: {
            name: @name,
          },
          spec: {
            request: Base64.strict_encode64(request.to_pem),
            usages: usages,
          }
        ))
      end

      # @param resource [Kubeclient::Resource]
      # @return [Kubeclient::Resource]
      def ensure_csr_approved(resource)
        resource_client = Kupo::Kube.client(@host.address, resource.apiVersion)

        unless resource[:status] && resource[:status][:conditions] && resource[:status][:conditions].any?{|c| c[:type] == 'Approved' }
          (resource[:status] ||= {})[:conditions] = [
            {'Type' => 'Approved'}
          ]

          resource_client.update_resource_approval(resource)
        end

        until resource[:status] && resource[:status][:certificate]
          sleep 1
          resource = resource_client.get_resource(resource)
        end

        resource
      end

      # @return [OpenSSL::X509::Certificate, Kubeclient::Resource]
      def ensure_client_certificate
        secret = ensure_secret do
          key = generate_private_key

          {'client-key.pem' => Base64.strict_encode64(key.to_pem)}
        end
        key = OpenSSL::PKey.read(Base64.strict_decode64(secret[:data]['client-key.pem']))

        resource = ensure_csr(key,
          subject_cn: @name,
          usages: [
            'digital signature',
            'key encipherment',
            'client auth',
          ],
        )
        resource = ensure_csr_approved(resource)

        cert = OpenSSL::X509::Certificate.new Base64.strict_decode64(resource[:status][:certificate])
        cert
      end
    end

    # @param master [Kupo::Configuration::Host]
    def initialize(master)
      @master = master
    end

    def call
      configure_metrics_server
      configure_heapster
    end

    def configure_metrics_server
      logger.info { "Provisioning client certificate for metrics-server ..." }
      cert_manager = CertManager.new(@master, 'metrics-server', namespace: 'kube-system')
      cert = cert_manager.ensure_client_certificate

      logger.info { "Configuring metrics-server ..." }
      Kupo::Kube.apply_stack(@master.address, 'metrics-server',
        version: '0.2.1',
        arch: @master.cpu_arch,
        client_cert: cert.to_pem,
      )
    end

    def configure_heapster
      logger.info { "Provisioning client certificate for heapster ..." }
      cert_manager = CertManager.new(@master, 'heapster', namespace: 'kube-system')
      cert = cert_manager.ensure_client_certificate

      logger.info { "Configuring heapster ..." }
      Kupo::Kube.apply_stack(@master.address, 'heapster',
        version: '1.5.1',
        arch: @master.cpu_arch,
        client_cert: cert.to_pem,
      )
    end
  end
end
