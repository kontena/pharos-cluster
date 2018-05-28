# frozen_string_literal: true

module Pharos
  module Phases
    class JoinNode < Pharos::Phase
      title "Join nodes"
      PROXY_ADDRESS = '127.0.0.1:6443'

      def already_joined?
        @ssh.file("/etc/kubernetes/kubelet.conf").exist?
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
        # CRI related pre-flight checks ignored as they cause false negative:
        # https://github.com/kubernetes/kubeadm/issues/814
        join_command << "--ignore-preflight-errors DirAvailable--etc-kubernetes-manifests,cri"

        @ssh.exec!('sudo ' + join_command.join(' '))
      end
    end
  end
end
