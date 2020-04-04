# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHelmController < Pharos::Phase
      title "Configure Helm Controller"

      HELM_CONTROLLER_VERSION = '0.4.1'

      register_component(
        name: 'helm-controller', version: HELM_CONTROLLER_VERSION, license: 'Apache License 2.0'
      )

      def call
        configure_helm_controller
      end

      def configure_helm_controller
        logger.info { "Configuring helm controller ..." }
        Retry.perform(logger: logger, exceptions: [K8s::Error::NotFound, K8s::Error::ServiceUnavailable]) do
          apply_stack(
            'helm-controller',
            version: HELM_CONTROLLER_VERSION
          )
        end
      end
    end
  end
end
