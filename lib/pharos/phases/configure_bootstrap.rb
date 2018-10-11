# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureBootstrap < Pharos::Phase
      title "Configure bootstrap tokens"

      def call
        if new_hosts?
          logger.info { "Creating node bootstrap token ..." }
          cluster_context['join-command'] = ssh.exec!("sudo kubeadm token create --print-join-command")
        else
          logger.info { "No new nodes, skipping bootstrap token creation ..." }
        end
      end

      def new_hosts?
        @config.worker_hosts.any? { |h| !h.checks['kubelet_configured'] }
      end
    end
  end
end
