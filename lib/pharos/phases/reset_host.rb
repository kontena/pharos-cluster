# frozen_string_literal: true

module Pharos
  module Phases
    class ResetHost < Pharos::Phase
      title "Reset hosts"

      on nil

      def call
        logger.info { "Removing all traces of Kontena Pharos ..." }
        host_configurer.reset
      end
    end
  end
end
