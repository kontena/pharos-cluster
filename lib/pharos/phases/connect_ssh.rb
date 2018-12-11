# frozen_string_literal: true

# frozen_stritiong_literal: true

module Pharos
  module Phases
    class ConnectSSH < Pharos::Phase
      title "Open SSH connection"

      def call
        host.ssh(non_interactive: true)
      rescue Net::SSH::AuthenticationFailed, Net::SSH::Authentication::KeyManagerError
        logger.error { "Authentication failed for #{host.user}@#{host}" }
      end
    end
  end
end
