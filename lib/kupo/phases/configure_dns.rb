require_relative 'base'

module Kupo::Phases
  class ConfigureDNS < Base
    # @param config [Kupo::Config]
    def initialize(master, config)
      @master = master
      @config = config
    end

    def call
      logger.info(@master.address) { "Patching kube-dns addon..." }
      patch_kubedns(replicas: @config.dns_replicas)
    end

    # @param replicas [Integer]
    def patch_kubedns(replicas: )
      kube_client = Kupo::Kube.update_resource(@master.address, Kubeclient::Resource.new({
        apiVersion: 'extensions/v1beta1',
        kind: 'Deployment',
        metadata: {
          namespace: 'kube-system',
          name: 'kube-dns',
        },
        spec: {
          replicas: replicas,
          template: {
            spec: {
              affinity: {
                podAntiAffinity: {
                  requiredDuringSchedulingIgnoredDuringExecution: [
                    {
                      labelSelector: {
                        matchExpressions: [
                          {
                            key: "k8s-app",
                            operator: "In",
                            values: [
                              "kube-dns",
                            ],
                          },
                        ],
                      },
                      topologyKey: "kubernetes.io/hostname",
                    },
                  ],
                },
              },
            },
          },
        },
      }))
    end
  end
end
