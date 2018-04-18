# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCalico < Pharos::Phase
      title "Configure Calico network"

      CALICO_VERSION = '3.1.0'

      register_component(
        Pharos::Phases::Component.new(
          name: 'calico-node', version: CALICO_VERSION, license: 'Apache License 2.0'
        )
      )

      register_component(
        Pharos::Phases::Component.new(
          name: 'calico-cni', version: CALICO_VERSION, license: 'Apache License 2.0'
        )
      )

      def validate
        case @host.cpu_arch.name
        when 'amd64'

        else
          fail "Unsupported CPU architecture: #{@host.cpu_arch.name}"
        end
      end

      def call
        validate

        logger.info { "Configuring overlay network ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'calico',
          ipv4_pool_cidr: @config.network.pod_network_cidr,
          version: CALICO_VERSION
        )
      end
    end
  end
end
