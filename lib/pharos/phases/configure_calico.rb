# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCalico < Pharos::Phase
      title "Configure Calico network"

      CALICO_VERSION = '3.1.3'

      register_component(
        name: 'calico-node', version: CALICO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network&.provider == 'calico' }
      )

      register_component(
        name: 'calico-cni', version: CALICO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network&.provider == 'calico' }
      )

      def validate
        fail "Unsupported CPU architecture: #{@host.cpu_arch.name}" unless @host.cpu_arch.name == 'amd64'
      end

      def call
        validate

        logger.info { "Configuring network ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'calico',
          image_repository: @config.image_repository,
          ipv4_pool_cidr: @config.network.pod_network_cidr,
          ipip_mode: @config.network.calico&.ipip_mode || 'Always',
          ipip_enabled: @config.network.calico&.ipip_mode != 'Never',
          master_ip: @config.master_host.peer_address,
          version: CALICO_VERSION
        )
      end
    end
  end
end
