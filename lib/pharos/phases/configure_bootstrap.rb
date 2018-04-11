# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureBootstrap < Pharos::Phase
      title "Configure bootstrap tokens"

      def call
        logger.info { "Creating node bootstrap token ..." }

        @config.join_command = @ssh.exec!("sudo kubeadm token create --print-join-command")
      end
    end
  end
end
