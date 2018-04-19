# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureNetwork < Pharos::Phase
      title "Configure network"

      WEAVE_VERSION = '2.3.0'

      register_component(
        Pharos::Phases::Component.new(
          name: 'weave-net', version: WEAVE_VERSION, license: 'Apache License 2.0'
        )
      )

      def call
        ensure_passwd
        ensure_resources
      end

      def ensure_passwd
        begin
          @kube.client.get_secret('weave-passwd', 'kube-system')
        rescue Kubeclient::ResourceNotFoundError
          logger.info { "Configuring overlay network shared secret ..." }
          weave_passwd = Kubeclient::Resource.new(
            metadata: {
              name: 'weave-passwd',
              namespace: 'kube-system'
            },
            data: {
              'weave-passwd': Base64.strict_encode64(generate_password)
            }
          )
          @kube.client.create_secret(weave_passwd)
        end
      end

      def ensure_resources
        trusted_subnets = @config.network.trusted_subnets || []
        logger.info { "Configuring overlay network ..." }

        @kube.stack('weave').apply(
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
