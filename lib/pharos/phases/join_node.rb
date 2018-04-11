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
        return if already_joined?

        logger.info { "Joining host to the master ..." }
        join_command = @config.join_command.split(' ')
        join_command = rewrite_api_address(join_command)
        if @host.container_runtime == 'cri-o'
          join_command << '--cri-socket /var/run/crio/crio.sock'
        end
        join_command << "--node-name #{@host.hostname}"
        join_command << "--ignore-preflight-errors DirAvailable--etc-kubernetes-manifests"

        @ssh.exec!('sudo ' + join_command.join(' '))
      end

      # @return [Array<String>]
      def rewrite_api_address(join_command)
        join_command.map { |c|
          if c.end_with?(':6443')
            PROXY_ADDRESS
          else
            c
          end
        }
      end
    end
  end
end
