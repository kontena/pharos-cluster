require_relative 'base'

module Kupo::Phases
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
      @ssh.file_exists?("/etc/kubernetes/kubelet.conf")
    end

    def call
      if already_joined?
        return
      end

      logger.info { "Joining host to the master ..." }
      join_command = 'sudo '
      @master_ssh.exec("sudo kubeadm token create --print-join-command") do |type, output|
        join_command << output
      end
      if @host.container_engine == 'cri-o'
        join_command = join_command.sub('kubeadm join', "kubeadm join --cri-socket /var/run/crio/crio.sock")
      end

      code = @ssh.exec(join_command) do |type, data|
        remote_output(type, data)
      end
      if code != 0
        raise Kupo::Error, "Failed to join host"
      end
    end
  end
end
