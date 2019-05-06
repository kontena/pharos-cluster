# frozen_string_literal: true

module Pharos
  module Phases
    class Drain < Pharos::Phase
      title "Drain node"

      def call
        mutex.synchronize do
          logger.info { "Draining ..." }
          master_host.transport.exec!("kubectl drain --grace-period=120 --force --timeout=5m --ignore-daemonsets --delete-local-data #{@host.hostname}")
        end
      rescue Pharos::ExecError => e
        logger.error { "failed to drain node: #{e.message}" }
      end
    end
  end
end
