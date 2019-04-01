# frozen_string_literal: true

module Pharos
  module Phases
    class DisconnectSSH < Pharos::Phase
      title "Disconnect SSH"

      def call
        transport.disconnect if transport.connected?
      end
    end
  end
end
