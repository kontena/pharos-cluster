# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureDNS < Pharos::Phase
      DNS_CACHE_STACK_NAME = 'node_local_dns'

      on :master_host

      title "Configure DNS"

      register_component(
        name: 'coredns', version: Pharos::COREDNS_VERSION, license: 'Apache License 2.0'
      )

      register_component(
        name: 'dns-node-cache', version: Pharos::DNS_NODE_CACHE_VERSION, license: 'Apache License 2.0'
      )

      def call
        verify_version
        patch_deployment(
          'coredns',
          replicas: @config.dns_replicas,
          max_surge: max_surge,
          max_unavailable: max_unavailable
        )

        if @config.network.node_local_dns_cache
          deploy_node_dns_cache
        else
          logger.info { "Removing node dns cache ..." }
          delete_stack(DNS_CACHE_STACK_NAME)
        end
      end

      def verify_version
        deployment = kube_resource_client.get('coredns')
        version = deployment.spec.template.spec.containers[0].image.split(':').last
        return if version == Pharos::COREDNS_VERSION

        raise Pharos::Error, "Invalid CoreDNS version #{version}, should be #{Pharos::COREDNS_VERSION}"
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

      def deploy_node_dns_cache
        logger.info { "Deploying node dns cache ..." }
        apply_stack(
          DNS_CACHE_STACK_NAME,
          version: Pharos::DNS_NODE_CACHE_VERSION,
          image_repository: @config.image_repository,
          nodelocal_dns: Pharos::Configuration::Network::CLUSTER_DNS,
          forward_target: dns_forward_target
        )
      end

      # @return [String]
      def dns_forward_target
        @config.network.service_cidr.gsub(%r{\.(\d+\/\d+)}, '.10')
      end
    end
  end
end
