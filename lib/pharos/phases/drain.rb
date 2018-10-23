# frozen_string_literal: true

module Pharos
  module Phases
    class Drain < Pharos::Phase
      title "Drain node"

      def call
        master_ssh.exec!("kubectl drain --force --timeout=5m --ignore-daemonsets --delete-local-data #{@host.hostname}")
      end
    end
  end
end
