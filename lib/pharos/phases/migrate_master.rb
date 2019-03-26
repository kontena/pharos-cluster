# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      title "Migrate master"

      on :master_hosts

      def call; end
    end
  end
end
