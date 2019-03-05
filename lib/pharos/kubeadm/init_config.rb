# frozen_string_literal: true

module Pharos
  module Kubeadm
    class InitConfig
      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
      end

      # @return [Hash]
      def generate
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1beta1',
          'kind' => 'InitConfiguration',
          'localApiEndpoint' => {
            'advertiseAddress' => advertise_address
          },
          'nodeRegistration' => {
            'name' => @host.hostname
          }
        }

        unless master_taint?
          config['nodeRegistration']['taints'] = []
        end

        if @host.crio?
          config['nodeRegistration']['criSocket'] = '/var/run/crio/crio.sock'
        end

        config
      end

      # Used for internal k8s api access (aka address that works without cni/overlay)
      #
      # @return [String]
      def advertise_address
        @config.regions.size == 1 ? @host.peer_address : @host.address
      end

      # @return [Boolean]
      def master_taint?
        return true unless @host.taints

        # matching the taint used by kubeadm
        @host.taints.any?{ |taint| taint.key == 'node-role.kubernetes.io/master' && taint.effect == 'NoSchedule' }
      end
    end
  end
end
