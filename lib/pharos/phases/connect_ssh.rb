# frozen_string_literal: true

module Pharos
  module Phases
    class ConnectSSH < Pharos::Phase
      title "Open SSH connection"

      def call
        Retry.perform(60, logger: logger, exceptions: [Net::SSH::Disconnect, Net::SSH::Timeout, Net::SSH::ConnectionTimeout]) do
          host.transport.connect
        end
      end
    end
  end
end
