# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureWeave < Pharos::Phase
      title "Configure Weave network"
      on :master

      WEAVE_VERSION = '2.4.1'

      register_component(
        name: 'weave-net', version: WEAVE_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network.provider == 'weave' }
      )

      def call
        ensure_passwd
        ensure_resources
      end

      def ensure_passwd
        kube_secrets = kube_client.api('v1').resource('secrets', namespace: 'kube-system')

        kube_secrets.get('weave-passwd')
      rescue K8s::Error::NotFound
        logger.info { "Configuring overlay network shared secret ..." }
        weave_passwd = K8s::Resource.new(
          metadata: {
            name: 'weave-passwd',
            namespace: 'kube-system'
          },
          data: {
            'weave-passwd': Base64.strict_encode64(generate_password)
          }
        )
        kube_secrets.create_resource(weave_passwd)
      end

      def ensure_resources
        trusted_subnets = @config.network.weave&.trusted_subnets || []
        logger.info { "Configuring overlay network ..." }
        apply_stack(
          'weave',
          image_repository: @config.image_repository,
          trusted_subnets: trusted_subnets,
          ipalloc_range: @config.network.pod_network_cidr,
          arch: @host.cpu_arch,
          version: WEAVE_VERSION
        )
      end

      def generate_password
        SecureRandom.hex(24)
      end
    end
  end
end
