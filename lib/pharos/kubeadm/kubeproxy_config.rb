# frozen_string_literal: true

module Pharos
  module Kubeadm
    class KubeProxyConfig
      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
      end

      # @return [Hash]
      def generate
        config = {
          'apiVersion' => 'kubeproxy.config.k8s.io/v1alpha1',
          'kind' => 'KubeProxyConfiguration',
          'mode' => @config.kube_proxy&.mode || 'iptables'
        }
        if @config.kube_proxy&.conntrack
          config['conntrack'] = @config.kube_proxy.conntrack
        end

        config
      end
    end
  end
end
