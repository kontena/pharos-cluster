# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      title "Migrate master"

      def call
        logger.info { 'Nothing to migrate.' }
      end
    end
  end
end
