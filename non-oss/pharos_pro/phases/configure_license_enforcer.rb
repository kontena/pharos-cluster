# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureLicenseEnforcer < Pharos::Phase
      title "Configure license enforcement"

      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources', 'license-enforcer'))).freeze

      def call
        logger.info { "Configuring icense enforcement on Pharos PRO ..." }
        logger.info { "Resource path: #{RESOURCE_PATH}" }

        stack = Pharos::Kube.stack('license-enforcer', RESOURCE_PATH)

        stack.apply(kube_client)
      end
    end
  end
end
