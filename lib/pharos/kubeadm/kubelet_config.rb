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
        if @config.kubelet&.system_reserved
          config['systemReserved'] = @config.kubelet.system_reserved
        end
        if @config.kubelet&.kube_reserved
          config['kubeReserved'] = @config.kubelet.kube_reserved
        end
        feature_gates = @config.kubelet&.feature_gates || {}
        if @config.cloud&.outtree_provider?
          feature_gates.merge!(@config.cloud.cloud_provider.feature_gates)
        end

        config['featureGates'] = feature_gates unless feature_gates.empty?

        config['cpuCFSQuotaPeriod'] = @config&.kubelet&.cpu_cfs_quota_period if @config&.kubelet&.cpu_cfs_quota_period
        config['cpuCFSQuota'] = !!@config&.kubelet&.cpu_cfs_quota

        config
      end
    end
  end
end
