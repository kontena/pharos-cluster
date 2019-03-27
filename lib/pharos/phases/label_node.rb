# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Configure node labels and taints"

      def call
        @config.hosts.each do |host|
          kube_nodes.update_resource(
            find_node(host).merge(host_patch_data(host))
          )
        end
      end

      def host_patch_data(host)
        {}.tap do |patch_data|
          patch_data[:metadata] = { labels: host.labels } # unless host.labels.empty? (they're never empty).
          patch_data[:spec] = { taints: host.taints.map(&:to_h) } unless host.taints.nil?
        end
      end

      def find_node(host)
        Pharos::Retry.perform(30, logger: logger, exceptions: [K8s::Error::NotFound]) do
          kube_nodes.get(host.hostname)
        end
      end

      def kube_nodes
        @kube_nodes ||= kube_client.api('v1').resource('nodes')
      end
    end
  end
end
