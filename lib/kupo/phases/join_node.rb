# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class JoinNode < Base
      # @param host [Kupo::Configuration::Host]
      # @param master [Kupo::Configuration::Host]
      def initialize(host, master)
        @host = host
        @master = master
        @ssh = Kupo::SSH::Client.for_host(@host)
        @master_ssh = Kupo::SSH::Client.for_host(@master)
      end

      def already_joined?
        @ssh.file("/etc/kubernetes/kubelet.conf").exist?
      end

      def call
        return if already_joined?

        logger.info { "Joining host to the master ..." }
        join_command = @master_ssh.exec!("sudo kubeadm token create --print-join-command")
        if @host.container_runtime == 'cri-o'
          join_command = join_command.sub('kubeadm join', "kubeadm join --cri-socket /var/run/crio/crio.sock")
        end

        @ssh.exec!('sudo ' + join_command)
      end
    end
  end
end
