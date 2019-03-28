# frozen_string_literal: true

module Pharos
  module Phases
    class JoinNode < Pharos::Phase
      title "Join nodes"
      def already_joined?
        transport.file("/etc/kubernetes/kubelet.conf").exist?
      end

      def call
        if already_joined?
          logger.info { "Already joined ..." }
          return
        end

        logger.info { "Joining host to the master ..." }
        join_command = cluster_context['join-command'].split(' ')
        if @host.container_runtime == 'cri-o'
          join_command << '--cri-socket /var/run/crio/crio.sock'
        end
        join_command << "--node-name #{@host.hostname}"
        join_command << "--ignore-preflight-errors DirAvailable--etc-kubernetes-manifests"
        join_command << "--ignore-preflight-errors SystemVerification" # kubeadm does not like fresh docker versions ...

        transport.exec!('sudo ' + join_command.join(' '))
      end
    end
  end
end
