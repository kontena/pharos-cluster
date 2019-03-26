# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      on :all_hosts

      def call
        if @host.labels.empty? && @host.taints.nil?
          logger.info { "No labels or taints set ... " }
          return
        end

        node = find_node
        raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

        logger.info { "Configuring node labels and taints ... " }
        patch_labels(node) unless @host.labels.empty?
        patch_taints(node) if @host.taints
      end

      # @param node [K8s::Resource]
      def patch_labels(node)
        kube_nodes.update_resource(
          node.merge(
            metadata: {
              labels: @host.labels
            }
          )
        )
      end

      # @param node [K8s::Resource]
      def patch_taints(node)
        kube_nodes.update_resource(
          node.merge(
            spec: {
              taints: @host.taints.map(&:to_h)
            }
          )
        )
      end

      def find_node
        node = nil
        retries = 0
        while node.nil? && retries < 10
          begin
            node = kube_nodes.get(@host.hostname)
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
