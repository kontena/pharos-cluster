# frozen_string_literal: true

module Pharos
  module Phases
    class DeleteHost < Pharos::Phase
      title "Delete node"

      def call
        mutex.synchronize do
          logger.info { "Deleting the node from Kubernetes API ..." }
          master_host.transport.exec!("kubectl delete node #{@host.hostname}")
        end
      rescue Pharos::ExecError => e
        logger.error { "Failed to delete node: #{e.message}" }
      end
    end
  end
end
