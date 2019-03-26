# frozen_string_literal: true

require_relative 'mixins/psp'

module Pharos
  module Phases
    class ConfigurePSP < Pharos::Phase
      include Pharos::Phases::Mixins::PSP
      title "Configure pod security policies"

      on :master_host

      def call
        logger.info { "Configuring default pod security policies ..." }
        apply_psp_stack
      end
    end
  end
end
