# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class JoinNode < Base
      def already_joined?
        @ssh.file_exists?("/etc/kubernetes/kubelet.conf")
      end

      def call
        if already_joined?
          return
        end

        logger.info { "Joining host to the master ..." }
        join_command = @master_ssh.exec!("sudo kubeadm token create --print-join-command").split(' ')
        if @host.container_runtime == 'cri-o'
          join_command << '--cri-socket /var/run/crio/crio.sock'
        end
        join_command << "--node-name #{@host.hostname}"

        @ssh.exec!('sudo ' + join_command.join(' '))
      end
    end
  end
end
