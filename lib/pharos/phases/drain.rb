# frozen_string_literal: true

module Pharos
  module Phases
    class Drain < Pharos::Phase
      title "Drain node"

      def call
        logger.info { "Draining ..." }
        mutex.synchronize { perform }
      end

      def perform
        master_host.transport.exec!("kubectl drain --grace-period=120 --force --timeout=5m --ignore-daemonsets --delete-local-data #{@host.hostname}")
      rescue Pharos::ExecError => ex
        logger.error { "Failed to drain node: #{ex.message}" }
      end
    end
  end
end
