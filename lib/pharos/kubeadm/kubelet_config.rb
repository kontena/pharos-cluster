# frozen_string_literal: true

module Pharos
  module Kubeadm
    class KubeletConfig
      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
      end

      # @return [Hash]
      def generate
        config = {
          'apiVersion' => 'kubelet.config.k8s.io/v1beta1',
          'kind' => 'KubeletConfiguration',
          'staticPodPath' => '/etc/kubernetes/manifests',
          'authentication' => {
            'webhook' => {
              'enabled' => true
            }
          },
          'serverTLSBootstrap' => true,
          'tlsCipherSuites' => ClusterConfig::TLS_CIPHERS.split(',')
        }

        config['clusterDNS'] = [Pharos::Configuration::Network::CLUSTER_DNS] if @config.network.node_local_dns_cache

        if @config.kubelet&.read_only_port
          config['readOnlyPort'] = 10_255
        end
        feature_gates = @config.kubelet&.feature_gates
        config['featureGates'] = feature_gates if feature_gates

        config
      end
    end
  end
end
