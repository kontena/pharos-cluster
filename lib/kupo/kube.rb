# frozen_string_literal: true

require 'kubeclient'
require 'deep_merge'
require 'openssl'
require 'base64'

module Kupo::Kube
  class Client < ::Kubeclient::Client
    def entities
      if @entities.empty?
        discover
      end
      @entities
    end

    def update_entity_approval(resource_name, entity_config)
      name      = entity_config[:metadata][:name]
      ns_prefix = build_namespace_prefix(entity_config[:metadata][:namespace])
      response = handle_exception do
        rest_client[ns_prefix + resource_name + "/#{name}/approval"]
          .put(entity_config.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(@headers))
      end
      format_response(@as, response.body)
    end

    def entity_for_resource(resource)
      name = Kubeclient::ClientMixin.underscore_entity(resource.kind.to_s)
      definition = entities[name]

      fail "Unknown entity for resource #{resource.kind} => #{name}" unless definition

      definition
    end

    def apis(options = {})
      response = rest_client.get(@headers)
      format_response(options[:as] || @as, response.body)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def update_resource(resource)
      definition = entity_for_resource(resource)

      old_resource = get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
      resource.metadata.resourceVersion = old_resource.metadata.resourceVersion
      merged_resource = Kubeclient::Resource.new(old_resource.to_h.deep_merge!(resource.to_h, overwrite_arrays: true))
      update_entity(definition.resource_name, merged_resource)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def update_resource_approval(resource)
      definition = entity_for_resource(resource)

      update_entity_approval(definition.resource_name, resource)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def create_resource(resource)
      definition = entity_for_resource(resource)

      create_entity(resource.kind, definition.resource_name, resource)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def get_resource(resource)
      definition = entity_for_resource(resource)

      get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
    end
  end

  RESOURCE_LABEL = 'kupo.kontena.io/stack'
  RESOURCE_ANNOTATION = 'kupo.kontena.io/stack-checksum'

  # @param host [String]
  # @return [Kubeclient::Client]
  def self.client(host, version = 'v1')
    @kube_client ||= {}
    unless @kube_client[version]
      config = Kubeclient::Config.read(File.join(Dir.home, ".kupo/#{host}"))
      path_prefix = version == 'v1' ? 'api' : 'apis'
      api_version, api_group = version.split('/').reverse
      @kube_client[version] = Kupo::Kube::Client.new(
        (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
        api_version,
        ssl_options: config.context.ssl_options,
        auth_options: config.context.auth_options
      )
    end
    @kube_client[version]
  end

  # @param host [String]
  # @return [Boolean]
  def self.config_exists?(host)
    File.exist?(File.join(Dir.home, ".kupo/#{host}"))
  end

  # @param host [Kupo::Configuration::Host]
  # @param stack [String]
  # @param vars [Hash]
  # @return [Array<Kubeclient::Resource>]
  def self.apply_stack(host, stack, vars = {})
    checksum = SecureRandom.hex(16)
    resources = []
    Dir.glob(File.join(__dir__, 'resources', stack, '*.yml')).each do |file|
      resource = parse_resource_file("#{stack}/#{File.basename(file)}", vars)
      resource.metadata.labels ||= {}
      resource.metadata.annotations ||= {}
      resource.metadata.labels[RESOURCE_LABEL] = stack
      resource.metadata.annotations[RESOURCE_ANNOTATION] = checksum
      apply_resource(host, resource)
      resources << resource
    end
    prune_stack(host, stack, checksum)

    resources
  end

  # @param host [Kupo::Configuration::Host]
  # @param stack [String]
  # @param checksum [String]
  # @return [Array<Kubeclient::Resource>]
  def self.prune_stack(host, stack, checksum)
    pruned = []
    client(host, '').apis.groups.each do |api_group|
      group_client = client(host, api_group.preferredVersion.groupVersion)
      group_client.entities.each do |type, meta|
        next if type.end_with?('_review')
        objects = group_client.get_entities(type, meta.resource_name, label_selector: "#{RESOURCE_LABEL}=#{stack}")
        objects.select { |obj|
          obj.metadata.annotations.nil? || obj.metadata.annotations[RESOURCE_ANNOTATION] != checksum
        }.each { |obj|
          obj.apiVersion = api_group.preferredVersion.groupVersion
          delete_resource(host, obj)
          pruned << obj
        }
      end
    end

    pruned
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.apply_resource(host, resource)
    resource_client = client(host, resource.apiVersion)

    begin
      resource_client.update_resource(resource)
    rescue Kubeclient::ResourceNotFoundError
      resource_client.create_resource(resource)
    end
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.create_resource(host, resource)
    resource_client = client(host, resource.apiVersion)
    resource_client.create_resource(resource)
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.update_resource(host, resource)
    resource_client = client(host, resource.apiVersion)
    resource_client.update_resource(resource)
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.get_resource(host, resource)
    resource_client = client(host, resource.apiVersion)
    resource_client.get_resource(resource)
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.delete_resource(host, resource)
    resource_client = client(host, resource.apiVersion)
    begin
      if resource.metadata.selfLink
        api_group = resource.metadata.selfLink.split("/")[1]
        resource_path = resource.metadata.selfLink.gsub("/#{api_group}/#{resource.apiVersion}", '')
        resource_client.rest_client[resource_path].delete
      else
        definition = resource_client.entities[underscore_entity(resource.kind.to_s)]
        resource_client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
        resource_client.delete_entity(
          definition.resource_name, resource.metadata.name, resource.metadata.namespace,
          kind: 'DeleteOptions',
          apiVersion: 'v1',
          propagationPolicy: 'Foreground'
        )
      end
    rescue Kubeclient::ResourceNotFoundError
      false
    end
  end

  # @param path [String]
  # @return [Kubeclient::Resource]
  def self.parse_resource_file(path, vars = {})
    yaml = File.read(File.realpath(File.join(__dir__, 'resources', path)))
    parsed_yaml = Kupo::Erb.new(yaml).render(vars)

    Kubeclient::Resource.new(YAML.safe_load(parsed_yaml))
  end

  # @param kind [String]
  # @return [String]
  def self.underscore_entity(kind)
    Kubeclient::ClientMixin.underscore_entity(kind.to_s)
  end

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
