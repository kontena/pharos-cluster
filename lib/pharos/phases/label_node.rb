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
        patch_node(node)
      end

      # @return [Array{Hash}]
      def taints
        return [] unless @host.taints

        @host.taints.map(&:to_h)
      end

      # @param node [Kubeclient::Resource]
      def patch_node(node)
        kube.patch_node(
          node.metadata.name,
          metadata: {
            labels: @host.labels || {}
          },
          spec: {
            taints: taints
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
