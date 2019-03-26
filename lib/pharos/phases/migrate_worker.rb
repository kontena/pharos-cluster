# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateWorker < Pharos::Phase
      title "Migrate worker"

      on :worker_hosts

      def call; end
    end
  end
end
