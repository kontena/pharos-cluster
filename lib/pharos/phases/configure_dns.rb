# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureDNS < Pharos::Phase
      title "Configure DNS"

      def call
        patch_deployment(
          'coredns',
          replicas: @config.dns_replicas,
          max_surge: max_surge,
          max_unavailable: max_unavailable
        )
      end

      # @return [Integer]
      def max_surge
        replicas = @config.dns_replicas
        nodes = @config.hosts.length

        if replicas == nodes
          # cannot create any extra replicas
          0
        elsif nodes <= replicas * 1.5
          # at most one per extra node
          nodes - replicas
        else
          # half
          (replicas * 0.5).floor
        end
      end

      # @return [Integer]
      def max_unavailable
        replicas = @config.dns_replicas

        if replicas == 1
          # must allow taking down all replicas
          1
        else
          # half
          (replicas * 0.5).floor
        end
      end

      # @return [K8s::Resource]
      def kube_resource_client
        kube_client.api('extensions/v1beta1').resource('deployments', namespace: 'kube-system')
      end

      # @param replicas [Integer]
      # @param nodes [Integer]
      def patch_deployment(name, replicas:, max_surge:, max_unavailable:)
        logger.info { "Patching #{name} deployment with #{replicas} replicas (max-surge #{max_surge}, max-unavailable #{max_unavailable})..." }

        spec = {
          replicas: replicas,
          strategy: {
            type: "RollingUpdate",
            rollingUpdate: {
              maxSurge: max_surge, # must be zero for a two-node cluster
              maxUnavailable: max_unavailable # must be at least one, even for a single-node cluster
            }
          },
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
                            values: ['kube-dns']
                          }
                        ]
                      },
                      topologyKey: "kubernetes.io/hostname"
                    }
                  ]
                }
              }
            }
          }
        }
        kube_resource_client.merge_patch(
          name,
          spec: spec
        )
      end
    end
  end
end
