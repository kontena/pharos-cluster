# frozen_string_literal: true

module Pharos
  module Phases
    class ConnectSSH < Pharos::Phase
      title "Open SSH connection"

      def call
        host.transport.connect
      end
    end
  end
end
