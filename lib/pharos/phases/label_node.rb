# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      def call
        unless @host.labels || @host.taints
          logger.info { "No labels or taints set ... " }
          return
        end

        node = find_node
        raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

        logger.info { "Configuring node labels and taints ... " }
        patch_labels(node) if @host.labels
        patch_taints(node) if @host.taints
      end

      # @param node [Kubeclient::Resource]
      def patch_labels(node)
        kube.patch_node(
          node.metadata.name,
          metadata: {
            labels: @host.labels
          },
        )
      end

      # @param node [Kubeclient::Resource]
      def patch_taints(node)
        kube.patch_node(
          node.metadata.name,
          spec: {
            taints: @host.taints.map(&:to_h)
          }
        )
      end

      def find_node
        node = nil
        retries = 0
        while node.nil? && retries < 10
          node = kube.get_nodes.find { |n|
            n.metadata.name == @host.hostname
          }
          unless node
            retries += 1
            sleep 2
          end
        end

        node
      end

      def kube
        @kube ||= Pharos::Kube.client(@master.api_address)
      end
    end
  end
end
