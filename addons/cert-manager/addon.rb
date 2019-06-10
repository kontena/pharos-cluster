# frozen_string_literal: true

Pharos.addon 'cert-manager' do
  version '0.7.2'
  license 'Apache License 2.0'

  issuer = custom_type {
    attribute :name, Pharos::Types::String
    attribute :server, Pharos::Types::String.optional
    attribute :email, Pharos::Types::String
  }

  ca_issuer = custom_type {
    attribute :enabled, Pharos::Types::Bool.default(true)
  }

  config {
    attribute :ca_issuer, ca_issuer.default(proc { ca_issuer.new(enabled: true) })
    attribute :extra_args, Pharos::Types::Array.default(proc { [] })
    attribute :issuers, Pharos::Types::Array.default(proc { [] })
    attribute :issuer, issuer # deprecated
  }

  config_schema {
    optional(:issuers).each(:hash?)
    optional(:extra_args).each(:str?)
    optional(:ca_issuer).schema {
      optional(:enabled).filled(:bool?)
    }

    # deprecated
    optional(:issuer).schema {
      required(:name).filled(:str?)
      required(:email).filled(:str?)
      optional(:server).filled(:str?)
    }

    # Register custom error for LE Acme v1 endpoint validation
    configure do
      def self.messages
        super.merge(en: { errors: { le_acme_v1: "Acme v1 is not supported by CertManager as of version 0.3.0, please change to Acme v2 endpoint!" } })
      end
    end

    validate(le_acme_v1: :issuer) do |i|
      if i && i[:name] == 'letsencrypt' && i[:server].include?('acme-v01.api.letsencrypt.org')
        false
      else
        true
      end
    end
  }

  install {
    # Need to add label to kube-system NS to get webhook PKI in place properly
    kube_client.api('v1').resource('namespaces').merge_patch('kube-system', metadata: { labels: { 'certmanager.k8s.io/disable-validation': "true" } })

    stack = kube_stack

    if config.ca_issuer&.enabled
      logger.info "Enabling kubernetes CA issuer ..."
      stack.resources << build_ca_secret
      config.issuers << build_ca_issuer.to_h
    end

    if config.issuer
      logger.warn "Issuer config option is deprecated, use issuers instead."
      config.issuers << build_legacy_issuer.to_h
    end

    stack.apply(kube_client)

    unless config.issuers.empty?
      logger.info "Applying issuers (this might take a moment) ..."
      issuers = config.issuers.map do |i|
        K8s::Resource.new(
          i.merge(
            apiVersion: "certmanager.k8s.io/v1alpha1"
          )
        )
      end
      issuers_stack = Pharos::Kube::Stack.new('cert-manager-issuers', issuers)
      Retry.perform(300, exceptions: [K8s::Error::InternalError]) do
        issuers_stack.apply(kube_client)
      end
    end
  }

  def build_ca_issuer
    K8s::Resource.new(
      apiVersion: "certmanager.k8s.io/v1alpha1",
      kind: "ClusterIssuer",
      metadata: {
        name: 'kube-ca-issuer'
      },
      spec: {
        ca: {
          secretName: 'kube-ca-secret'
        }
      }
    )
  end

  def build_ca_secret
    K8s::Resource.new(
      apiVersion: "v1",
      kind: "Secret",
      type: "kubernetes.io/tls",
      metadata: {
        name: "kube-ca-secret",
        namespace: "kube-system"
      },
      data: {
        'tls.crt': Base64.strict_encode64(master_host.transport.file('/etc/kubernetes/pki/ca.crt').read),
        'tls.key': Base64.strict_encode64(master_host.transport.file('/etc/kubernetes/pki/ca.key').read)
      }
    )
  end

  def build_legacy_issuer
    K8s::Resource.new(
      apiVersion: "certmanager.k8s.io/v1alpha1",
      kind: "Issuer",
      metadata: {
        name: config.issuer.name,
        namespace: "default"
      },
      spec: {
        acme: {
          server: config.issuer.server,
          email: config.issuer.email,
          privateKeySecretRef: {
            name: config.issuer.name
          },
          http01: {}
        }
      }
    )
  end

  def master_host
    @master_host ||= cluster_config.master_host
  end
end
