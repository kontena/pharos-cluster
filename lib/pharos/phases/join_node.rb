# frozen_string_literal: true

module Pharos
  module Phases
    class JoinNode < Pharos::Phase
      title "Join nodes"

      def already_joined?
        @ssh.file("/etc/kubernetes/kubelet.conf").exist?
      end

      def call
        return if already_joined?

        logger.info { "Joining host to the master ..." }
        join_command = @config.join_command.split(' ')
        if @host.container_runtime == 'cri-o'
          join_command << '--cri-socket /var/run/crio/crio.sock'
        end
        join_command << "--node-name #{@host.hostname}"

        @ssh.exec!('sudo ' + join_command.join(' '))
      end
    end
  end
end
