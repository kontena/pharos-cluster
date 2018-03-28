# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ConfigureNetwork < Base
      WEAVE_VERSION = '2.2.1'

      register_component(
        Kupo::Phases::Component.new(
          name: 'weave-net', version: WEAVE_VERSION, license: 'Apache License 2.0'
        )
      )

      # @param master [Kupo::Configuration::Host]
      # @param config [Kupo::Configuration::Network]
      def initialize(master, config)
        @master = master
        @config = config
      end

      def call
        configure_cni
        ensure_passwd
        ensure_resources
      end

      def ensure_passwd
        kube_client = Kupo::Kube.client(@master.address)
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
        trusted_subnets = @config.trusted_subnets || []
        logger.info { "Configuring overlay network ..." }
        Kupo::Kube.apply_stack(
          @master.address, 'weave',
          trusted_subnets: trusted_subnets,
          ipalloc_range: @config.pod_network_cidr,
          arch: @master.cpu_arch,
          version: WEAVE_VERSION
        )
      end

      def configure_cni
        exec_script('configure-weave-cni.sh')
      end

      def generate_password
        SecureRandom.hex(24)
      end
    end
  end
end
