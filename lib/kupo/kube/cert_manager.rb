require 'openssl'
require 'base64'

module Kupo::Kube
  # Manage kube certificates and private key secrets.
  #
  # Generates a v1 secret and certificates.k8s.io/v1beta1 csr with the given name.
  # The secret is used to persist the private key, and the csr is used to obtain the signed certificate.
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

    # @return [OpenSSL::X509::Name]
    def build_subject(cn:)
      name = OpenSSL::X509::Name.new
      name.add_entry('CN', cn)
      name
    end

    # @param key [OpenSSL::PKey]
    # @param subject [OpenSSL::X509::Name]
    # @return [OpenSSL::X509::Request]
    def build_request(key, subject)
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = key.public_key
      req.sign(key, OpenSSL::Digest::SHA256.new)
      req
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
      resource_client = Kupo::Kube.client(@host.address, resource.apiVersion)

      begin
        resource = resource_client.get_resource(resource)
      rescue Kubeclient::ResourceNotFoundError
        resource[:data] = yield
        resource = resource_client.create_resource(resource)
      end

      resource
    end

    # @param req [OpenSSL::X509::Request]
    # @param usages [Array<String>]
    # @return [Kubeclient::Resource]
    def ensure_csr(req, usages: )
      resource = Kubeclient::Resource.new(
        apiVersion: 'certificates.k8s.io/v1beta1',
        kind: 'CertificateSigningRequest',
        metadata: {
          name: @name,
        },
        spec: {
          request: Base64.strict_encode64(req.to_pem),
          usages: usages,
        }
      )
      resource_client = Kupo::Kube.client(@host.address, resource.apiVersion)

      begin
        # TODO: update/re-create if spec.request does not match, or cert is expiring...?
        resource = resource_client.get_resource(resource)
      rescue Kubeclient::ResourceNotFoundError
        resource = resource_client.create_resource(resource)
      end

      resource
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def ensure_csr_approved(resource)
      resource_client = Kupo::Kube.client(@host.address, resource.apiVersion)

      resource.status.conditions ||= []

      unless resource.status.conditions.any?{|c| c[:type] == 'Approved' }
        resource.status.conditions << {
          type: 'Approved',
          reason: 'KupoApproved',
          message: "Self-approving #{@name} certificate",
        }

        resource_client.update_resource_approval(resource)
      end

      until resource.status.certificate
        sleep 1
        resource = resource_client.get_resource(resource)
      end

      resource
    end

    # @param secret_filename [String] secret.data key, filename when the secret is mounted as a volume
    # @return [OpenSSL::PKey]
    def ensure_key(secret_filename: )
      secret = ensure_secret do
        key = generate_private_key

        {secret_filename => Base64.strict_encode64(key.to_pem)}
      end

      key = OpenSSL::PKey.read(Base64.strict_decode64(secret[:data][secret_filename]))
      key
    end

    # @param key [OpenSSL::PKey]
    # @param subject [OpenSSL::X509::Name]
    # @param usages [Array<String>]
    # @return [OpenSSL::X509::Certificate]
    def ensure_certificate(key, subject, usages: )
      req = build_request(key, subject)
      resource = ensure_csr(req,
        usages: usages,
      )
      resource = ensure_csr_approved(resource)

      cert = OpenSSL::X509::Certificate.new Base64.strict_decode64(resource[:status][:certificate])
      cert
    end

    # Generates a secret containing the `client-key.pem` for use with the returned client cert.
    #
    # @return [OpenSSL::X509::Certificate, OpenSSL::PKey]
    def ensure_client_certificate
      key = ensure_key(secret_filename: 'client-key.pem')
      subject = build_subject(cn: @name)
      cert = ensure_certificate(key, subject,
        usages: [
          'digital signature',
          'key encipherment',
          'client auth',
        ],
      )

      return [cert, key]
    end
  end
end
