# frozen_string_literal: true

module Pharos
  module Phases
    class DeleteHost < Pharos::Phase
      title "Delete node"

      def call
        master_ssh.exec!("kubectl delete node #{@host.hostname}")
      end
    end
  end
end
