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
          'tlsCipherSuites' => ClusterConfig::TLS_CIPHERS.split(','),
          'clusterDNS' => [
            Pharos::Configuration::Network::CLUSTER_DNS
          ]
        }
        if @config.kubelet&.read_only_port
          config['readOnlyPort'] = 10_255
        end
        feature_gates = @config.kubelet&.feature_gates || {}
        if @config.cloud.outtree_provider?
          feature_gates.merge!(@config.cloud.cloud_provider.feature_gates)
        end

        config['featureGates'] = feature_gates unless feature_gates.empty?
        config
      end
    end
  end
end
