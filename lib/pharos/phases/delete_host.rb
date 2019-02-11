# frozen_string_literal: true

module Pharos
  module Phases
    class DeleteHost < Pharos::Phase
      title "Delete node"

      def call
        logger.info { "deleting node from kubernetes api ..." }
        master_host.transport.exec!("kubectl delete node #{@host.hostname}")
      rescue Pharos::ExecError => ex
        logger.error { "failed to delete node: #{ex.message}" }
      end
    end
  end
end
