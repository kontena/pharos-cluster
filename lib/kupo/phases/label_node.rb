# frozen_string_literal: true

require_relative 'base'

module Kupo::Phases
  class LabelNode < Base
    def initialize(host, master)
      @host = host
      @master = master
    end

    def call
      return unless @host.labels

      node = find_node
      if node
        logger.info { "Configuring node labels ... " }
        patch_node(node)
      else
        raise Kupo::Error, "Cannot set labels, node not found"
      end
    end

    # @param node [Kubeclient::Resource]
    def patch_node(node)
      kube.patch_node(node.metadata.name,
                      metadata: {
                        labels: @host.labels
                      })
    end

    def find_node
      internal_ip = @host.private_address || @host.address
      node = nil
      retries = 0
      while node.nil? && retries < 10
        node = kube.get_nodes.find { |n|
          n.status.addresses.any? { |a| a.type == 'InternalIP' && a.address == internal_ip }
        }
        unless node
          retries += 1
          sleep 2
        end
      end

      node
    end

    def kube
      @kube ||= Kupo::Kube.client(@master.address)
    end
  end
end
