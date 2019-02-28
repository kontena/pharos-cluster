# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureWeave < Pharos::Phase
      title "Configure Weave network"

      WEAVE_VERSION = '2.5.1'
      WEAVE_FLYING_SHUTTLE_VERSION = '0.1.1'

      register_component(
        name: 'weave-net', version: WEAVE_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network.provider == 'weave' }
      )

      register_component(
        name: 'weave-flying-shuttle', version: WEAVE_FLYING_SHUTTLE_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network.provider == 'weave' }
      )

      def call
        configure_cni
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
          version: WEAVE_VERSION,
          firewalld_enabled: !!@config.network&.firewalld&.enabled,
          flying_shuttle_enabled: @config.regions.size > 1,
          flying_shuttle_version: WEAVE_FLYING_SHUTTLE_VERSION,
          no_masq_local: @config.network.weave&.no_masq_local || false
        )
      end

      def generate_password
        SecureRandom.hex(24)
      end

      def configure_cni
        exec_script('configure-weave-cni.sh')
      end
    end
  end
end
