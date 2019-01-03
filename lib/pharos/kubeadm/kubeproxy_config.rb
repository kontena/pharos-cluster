# frozen_string_literal: true

module Pharos
  module Kubeadm
    class KubeProxyConfig
      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
        @init_config = InitConfig.new(config, host)
      end

      # @return [Hash]
      def generate
        config = {
          'apiVersion' => 'kubeproxy.config.k8s.io/v1alpha1',
          'kind' => 'KubeProxyConfiguration',
          'mode' => @config.kube_proxy&.mode || 'iptables'
        }

        config
      end
    end
  end
end
