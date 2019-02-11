# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureWeave < Pharos::Phase
      title "Configure Weave network"

      WEAVE_VERSION = '2.5.0'
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
            'weave-passwd': Base64.strict_encode64(@config.network.weave&.passwd || generate_password)
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
          firewalld_enabled: firewalld?,
          known_peers: known_peers,
          flying_shuttle_enabled: flying_shuttle?,
          flying_shuttle_version: WEAVE_FLYING_SHUTTLE_VERSION,
          no_masq_local: no_masq_local?
        )
      end

      # @return [Array<String>]
      def known_peers
        configmap = kube_client.api('v1').resource('configmaps', namespace: 'kube-system').get('flying-shuttle')
        return initial_known_peers unless configmap.data['known-peers']

        JSON.parse(configmap.data['known-peers'])['peers']
      rescue K8s::Error::NotFound
        initial_known_peers
      end

      # @return [Array<String>, NilClass]
      def initial_known_peers
        @config.network.weave&.known_peers
      end

      # @return [Boolean]
      def firewalld?
        !!@config.network&.firewalld&.enabled
      end

      # @return [Boolean]
      def flying_shuttle?
        return true if @config.network.weave&.known_peers
        return true if @config.regions.size > 1

        @config.network.weave&.flying_shuttle || false
      end

      # @return [Boolean]
      def no_masq_local?
        @config.network.weave&.no_masq_local || false
      end

      # @return [String]
      def generate_password
        SecureRandom.hex(24)
      end

      def configure_cni
        exec_script('configure-weave-cni.sh')
      end
    end
  end
end
