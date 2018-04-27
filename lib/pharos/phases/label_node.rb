# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      def call
        unless @host.labels
          logger.info { "No labels set ... " }
          return
        end

        node = find_node
        raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

        logger.info { "Configuring node labels ... " }
        patch_node(node)
      end

      # @param node [Kubeclient::Resource]
      def patch_node(node)
        @kube.client.patch_node(
          node.metadata.name,
          metadata: {
            labels: @host.labels
          }
        )
      end

      def find_node
        internal_ip = @host.peer_address
        node = nil
        retries = 0
        while node.nil? && retries < 10
          node = @kube.client.get_nodes.find { |n|
            n.status.addresses.any? { |a| a.type == 'InternalIP' && a.address == internal_ip }
          }
          unless node
            retries += 1
            sleep 2
          end
        end

        node
      end
    end
  end
end
