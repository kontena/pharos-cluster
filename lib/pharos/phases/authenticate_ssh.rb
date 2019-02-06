# frozen_string_literal: true

module Pharos
  module Phases
    class AuthenticateSSH < Pharos::Phase
      title "Authenticate SSH connection"

      def call
        return if host.local?

        host.ssh(non_interactive: false)
        logger.info { "Authenticated as #{host.user}@#{host}" }
      end
    end
  end
end
