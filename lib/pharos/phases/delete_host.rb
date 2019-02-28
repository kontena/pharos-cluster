# frozen_string_literal: true

module Pharos
  module Phases
    class DeleteHost < Pharos::Phase
      title "Delete node"

      def call
        mutex.synchronize do
          logger.info { "Deleting node from kubernetes api ..." }
          master_host.transport.exec!("kubectl delete node #{@host.hostname}")
        end
      rescue Pharos::ExecError => ex
        logger.error { "Failed to delete node: #{ex.message}" }
      end
    end
  end
end
