# frozen_string_literal: true

module Pharos
  module Phases
    class Drain < Pharos::Phase
      title "Drain node"

      def call
        logger.info { "draining ..." }
        master_ssh.exec!("kubectl drain --grace-period=120 --force --timeout=5m --ignore-daemonsets --delete-local-data #{@host.hostname}")
      rescue Pharos::SSH::RemoteCommand::ExecError => ex
        logger.error { "failed to drain node: #{ex.message}" }
      end
    end
  end
end
