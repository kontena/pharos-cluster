# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCustomNetwork < Pharos::Phase
      title "Configure Custom network"

      def call
        logger.info { "Configuring custom network ..." }
        stack = Pharos::Kube.stack('custom-network', @config.network.custom.manifest_path, name: 'custom_network', cluster_config: @config)
        stack.apply(kube_client)
      end
    end
  end
end
