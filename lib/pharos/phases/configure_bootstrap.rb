# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureBootstrap < Pharos::Phase
      title "Configure bootstrap tokens"
      runs_on :master_host
      uses_ssh

      def call
        logger.info { "Creating node bootstrap token ..." }

        cluster_context['join-command'] = @ssh.exec!("sudo kubeadm token create --print-join-command")
      end
    end
  end
end
