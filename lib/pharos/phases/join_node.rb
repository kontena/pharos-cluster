# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class JoinNode < Base
      def already_joined?
        @ssh.file_exists?("/etc/kubernetes/kubelet.conf")
      end

      def call(join_command)
        return if already_joined?

        logger.info { "Joining host to the master ..." }
        join_command = @master.join_command.dup
        if @host.container_runtime == 'cri-o'
          join_command << '--cri-socket /var/run/crio/crio.sock'
        end
        join_command << "--node-name #{@host.hostname}"

        @ssh.exec!('sudo ' + join_command.join(' '))
      end
    end
  end
end
