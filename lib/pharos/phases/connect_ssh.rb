# frozen_string_literal: true

module Pharos
  module Phases
    class ConnectSSH < Pharos::Phase
      title "Open SSH connection"

      on :remote_hosts

      def call
        host.transport.connect unless host.transport.connected?
      end
    end
  end
end
