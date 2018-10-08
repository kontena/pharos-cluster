# frozen_string_literal: true

Pharos.addon 'cert-manager' do
  version '0.5.0'
  license 'Apache License 2.0'

  issuer = custom_type {
    attribute :name, Pharos::Types::String
    attribute :server, Pharos::Types::String.optional
    attribute :email, Pharos::Types::String.default('https://acme-v01.api.letsencrypt.org/directory')
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

    migrate_acme_v2
  }

  def migrate_acme_v2
    kube_client.api('certmanager.k8s.io/v1alpha1').resource('issuers', namespace: nil).list.each do |issuer|
      next unless issuer.spec.acme.server == 'https://acme-v01.api.letsencrypt.org/directory'

      spec = {
        acme: {
          server: 'https://acme-v02.api.letsencrypt.org/directory'
        }
      }
      rc = kube_client.client_for_resource(issuer, namespace: issuer.metadata.namespace)
      rc.merge_patch(issuer.metadata.name, { spec: spec }, namespace: issuer.metadata.namespace, strategic_merge: false)
    end
  end
end
