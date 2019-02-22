# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureLicenseEnforcer < Pharos::Phase
      title "Configure license enforcement"

      LICENSE_ENFORCER_VERSION = '0.1.0'
      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources', 'license-enforcer'))).freeze

      register_component(
        name: 'PHAROS-LICENSE-ENFORCER', version: LICENSE_ENFORCER_VERSION, license: 'Kontena License'
      )

      def enabled?
        true
      end

      def call
        logger.info { "Configuring icense enforcement on Pharos PRO ..." }

        stack = Pharos::Kube.stack(
          'license-enforcer',
          RESOURCE_PATH,
          version: LICENSE_ENFORCER_VERSION,
          image_repository: @config.image_repository
        )

        stack.apply(kube_client)
      end
    end
  end
end
