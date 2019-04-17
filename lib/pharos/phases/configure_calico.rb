# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCalico < Pharos::Phase
      title "Configure Calico network"

      CALICO_VERSION = '3.6.0'

      register_component(
        name: 'calico-node', version: CALICO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network&.provider == 'calico' }
      )

      register_component(
        name: 'calico-cni', version: CALICO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network&.provider == 'calico' }
      )

      register_component(
        name: 'calico-kube-controllers', version: CALICO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network&.provider == 'calico' }
      )

      # @param name [String]
      # @return [K8s::Resource, nil]
      def get_ippool(name)
        kube_client.api('crd.projectcalico.org/v1').resource('ippools').get(name)
      rescue K8s::Error::NotFound
        # handles both CRD not found, or ippool not found
        nil
      end

      # @raise [StandardError]
      def validate_ippool
        return unless ippool = get_ippool('default-ipv4-ippool')

        return if ippool.spec.cidr == @config.network.pod_network_cidr

        fail "cluster.yml network.pod_network_cidr has been changed: cluster has #{ippool.spec.cidr}, config has #{@config.network.pod_network_cidr}"
      end

      def validate
        fail "Unsupported CPU architecture: #{@host.cpu_arch.name}" unless @host.cpu_arch.name == 'amd64'

        validate_ippool
      end

      def call
        validate

        logger.info { "Configuring network ..." }
        apply_stack(
          'calico',
          image_repository: @config.image_repository,
          ipv4_pool_cidr: @config.network.pod_network_cidr,
          ipip_mode: @config.network.calico&.ipip_mode || 'Always',
          ipip_enabled: @config.network.calico&.ipip_mode != 'Never',
          master_ip: master_host.peer_address,
          version: CALICO_VERSION,
          nat_outgoing: @config.network.calico&.nat_outgoing,
          firewalld_enabled: !!@config.network&.firewalld&.enabled,
          reload_iptables: !!cluster_context['reload-iptables'],
          envs: @config.network.calico&.environment || {},
          metrics_enabled: metrics_enabled?,
          metrics_port: metrics_port,
          mtu: @config.network.calico&.mtu || 1500
        )
      end

      def metrics_enabled?
        !!@config.network.calico&.environment&.dig('FELIX_PROMETHEUSMETRICSENABLED')
      end

      def metrics_port
        @config.network.calico&.environment&.dig('FELIX_PROMETHEUSMETRICSPORT') || 9091
      end
    end
  end
end
