# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureLicenseEnforcer < Pharos::Phase
      title "Configure license enforcement"

      def enabled?
        false
      end
    end
  end
end
