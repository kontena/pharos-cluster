# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureDNS < Base
      PHASE_TITLE = "Configure DNS"

      def call
        patch_kubedns(
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

      # @param replicas [Integer]
      # @param nodes [Integer]
      def patch_kubedns(replicas:, max_surge:, max_unavailable:)
        logger.info { "Patching kube-dns addon with #{replicas} replicas (max-surge #{max_surge}, max-unavailable #{max_unavailable})..." }

        Pharos::Kube.update_resource(
          @master.address,
          Kubeclient::Resource.new(
            apiVersion: 'extensions/v1beta1',
            kind: 'Deployment',
            metadata: {
              namespace: 'kube-system',
              name: 'kube-dns'
            },
            spec: {
              replicas: replicas,
              strategy: {
                type: "RollingUpdate",
                rollingUpdate: {
                  maxSurge: max_surge, # must be zero for a two-node cluster
                  maxUnavailable: max_unavailable, # must be at least one, even for a single-node cluster
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
                                values: [
                                  "kube-dns"
                                ]
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
          )
        )
      end
    end
  end
end
