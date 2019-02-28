# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      def call
        @config.hosts.each do |host|
          if host.labels.empty? && host.taints.nil?
            logger.debug { "No labels or taints set for #{host}... " }
            next
          end

          node = find_node(host.hostname)
          raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

          logger.info { "Configuring node labels and taints for #{host}... " }
          patch_labels(node, host.labels) unless host.labels.empty?
          patch_taints(node, host.taints) if host.taints
        end
      end

      # @param node [K8s::Resource]
      def patch_labels(node, labels)
        kube_nodes.update_resource(
          node.merge(
            metadata: {
              labels: labels
            }
          )
        )
      end

      # @param node [K8s::Resource]
      def patch_taints(node, taints)
        kube_nodes.update_resource(
          node.merge(
            spec: {
              taints: taints.map(&:to_h)
            }
          )
        )
      end

      def find_node(hostname)
        node = nil
        retries = 0
        while node.nil? && retries < 10
          begin
            node = kube_nodes.get(hostname)
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
        kube_client.api('v1').resource('nodes')
      end
    end
  end
end
