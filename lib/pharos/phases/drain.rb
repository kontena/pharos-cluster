# frozen_string_literal: true

module Pharos
  module Phases
    class Drain < Pharos::Phase
      title "Drain node"

      on nil

      def call
        logger.info { "draining ..." }
        master_host.transport.exec!("kubectl drain --grace-period=120 --force --timeout=5m --ignore-daemonsets --delete-local-data #{@host.hostname}")
      rescue Pharos::ExecError => ex
        logger.error { "failed to drain node: #{ex.message}" }
      end
    end
  end
end
