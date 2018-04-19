# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureNetwork < Pharos::Phase
      title "Configure network"

      register_component 'weave-net', version: '2.3.0', license: 'Apache License 2.0'

      def call
        ensure_passwd
        ensure_resources
      end

      def ensure_passwd
        kube_client = Pharos::Kube.client(@master.api_address)
        begin
          kube_client.get_secret('weave-passwd', 'kube-system')
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
          kube_client.create_secret(weave_passwd)
        end
      end

      def ensure_resources
        trusted_subnets = @config.network.trusted_subnets || []
        logger.info { "Configuring overlay network ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'weave',
          trusted_subnets: trusted_subnets,
          ipalloc_range: @config.network.pod_network_cidr,
          arch: @host.cpu_arch,
          version: components.weave_net.version
        )
      end

      def generate_password
        SecureRandom.hex(24)
      end
    end
  end
end
