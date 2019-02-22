# frozen_string_literal: true

require_relative 'mixins/psp'

module Pharos
  module Phases
    class ConfigureLicenseEnforcer < Pharos::Phase
      title "Configure license enforcement"

      def enabled?
        false
      end

      def call
        logger.info { "No license enforcement on Pharos OSS ..." }
      end
    end
  end
end
