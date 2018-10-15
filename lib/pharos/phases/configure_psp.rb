# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigurePSP < Pharos::Phase
      title "Configure pod security policies"

      def call
        logger.info { "Configuring default pod security policies ..." }
        apply_stack(
          'psp',
          default_psp: @config.pod_security_policy.default_policy
        )
      end
    end
  end
end
