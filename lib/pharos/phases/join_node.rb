# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class JoinNode < Base
      # @param host [Pharos::Configuration::Host]
      # @param master [Pharos::Configuration::Host]
      def initialize(host, master)
        @host = host
        @master = master
        @ssh = Pharos::SSH::Client.for_host(@host)
        @master_ssh = Pharos::SSH::Client.for_host(@master)
      end

      def already_joined?
        @ssh.file("/etc/kubernetes/kubelet.conf").exist?
      end

      def call
        return if already_joined?

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
