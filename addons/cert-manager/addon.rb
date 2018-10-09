# frozen_string_literal: true

Pharos.addon 'cert-manager' do
  version '0.5.0'
  license 'Apache License 2.0'

  issuer = custom_type {
    attribute :name, Pharos::Types::String
    attribute :server, Pharos::Types::String.optional
    attribute :email, Pharos::Types::String
  }

  config {
    attribute :issuer, issuer
  }

  config_schema {
    required(:issuer).schema {
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
      if i[:name] == 'letsencrypt' && i[:server].include?('acme-v01.api.letsencrypt.org')
        false
      else
        true
      end
    end
  }

  install {
    apply_resources

    migrate_le_acme_issuers
    migrate_le_acme_cluster_issuers
  }

  def patch_spec
    {
      acme: {
        server: 'https://acme-v02.api.letsencrypt.org/directory'
      }
    }
  end

  def le_acme_v1_endpoint
    'https://acme-v01.api.letsencrypt.org/directory'
  end

  def migrate_le_acme_issuers
    kube_client.api('certmanager.k8s.io/v1alpha1').resource('issuers', namespace: nil).list.each do |issuer|
      next unless issuer.spec.acme.server == le_acme_v1_endpoint

      rc = kube_client.client_for_resource(issuer, namespace: issuer.metadata.namespace)
      rc.merge_patch(issuer.metadata.name, { spec: patch_spec }, namespace: issuer.metadata.namespace, strategic_merge: false)
    end
  end

  def migrate_le_acme_cluster_issuers
    kube_client.api('certmanager.k8s.io/v1alpha1').resource('clusterissuers', namespace: nil).list.each do |issuer|
      next unless issuer.spec.acme.server == le_acme_v1_endpoint

      rc = kube_client.client_for_resource(issuer)
      rc.merge_patch(issuer.metadata.name, { spec: patch_spec }, strategic_merge: false)
    end
  end
end
