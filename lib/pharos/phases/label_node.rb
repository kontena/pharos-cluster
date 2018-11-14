# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      def call
        mutex.synchronize { perform }
      end

      def perform
          logger.info { "No labels or taints set ... " }
          return
        end

        config.hosts.each do |host|
          if host.labels.empty? && @host.taints.nil?
            logger.info { "No labels or taints set for #{host} ... " }
          end

          node = find_node(host)
          raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

          logger.info { "Configuring node labels and taints for #{host.address} ... " }
          patch_labels(node, host) if host.labels
          patch_taints(node, host) if host.taints
        end
      end

      # @param node [K8s::Resource]
      # @param host [Pharos::Configuration::Host]
      def patch_labels(node, host)
        kube_nodes.update_resource(
          node.merge(
            metadata: {
              labels: host.labels
            }
          )
        )
      end

      # @param node [K8s::Resource]
      # @param host [Pharos::Configuration::Host]
      def patch_taints(node, host)
        kube_nodes.update_resource(
          node.merge(
            spec: {
              taints: host.taints.map(&:to_h)
            }
          )
        )
      end

      def find_node(host)
        node = nil
        retries = 0
        while node.nil? && retries < 10
          begin
            node = kube_nodes.get(host.hostname)
          rescue K8s::Error::NotFound
            retries += 1
            sleep 2
          else
            break
          end
        end

        node
      end

      def kube_nodes
        @kube_nodes ||= kube_client.api('v1').resource('nodes')
      end
    end
  end
end
