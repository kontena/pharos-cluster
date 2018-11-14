# frozen_string_literal: true

module Pharos
  module Phases
    class DeleteHost < Pharos::Phase
      title "Delete node"

      def call
        logger.info { "deleting node from kubernetes api ..." }
        mutex.synchronize { perform }
      end

      def perform
        master_ssh.exec!("kubectl delete node #{@host.hostname}")
      rescue Pharos::SSH::RemoteCommand::ExecError => ex
        logger.error { "failed to delete node: #{ex.message}" }
      end
    end
  end
end
