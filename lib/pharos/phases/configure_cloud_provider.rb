# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCloudProvider < Pharos::Phase
      title "Configure cloud provider"

      def call
        unless @config.cloud&.provider
          logger.info "Cloud provider not set, skipping."
          return
        end

        if @config.cloud.intree_provider?
          logger.info "In-tree cloud provider #{@config.cloud.provider} enabled."
        elsif @config.cloud.outtree_provider?
          logger.info "Configuring cloud provider #{@config.cloud.provider} ..."
          apply_cloud_config
        else
          logger.info "Using external cloud provider, provider needs to be configured manually."
        end
      end

      def apply_cloud_config
        apply_stack('csi-crds') if @config.cloud.cloud_provider.csi?
        if @config.cloud.config
          stack = Pharos::Kube::Stack.load("#{@config.cloud.provider}-cloud-config", @config.cloud.config)
          stack.apply(kube_client)
        end
        apply_stack(@config.cloud.provider)
      end
    end
  end
end
