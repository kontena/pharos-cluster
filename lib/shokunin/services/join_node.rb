require_relative 'logging'

module Shokunin::Services
  class JoinNode
    include Shokunin::Services::Logging

    def initialize(host, master)
      @host = host
      @master = master
      @ssh = Shokunin::SSH::Client.for_host(@host)
      @master_ssh = Shokunin::SSH::Client.for_host(@master)
    end

    def already_joined?
      @ssh.file_exists?("/etc/kubernetes/kubelet.conf")
    end

    def call
      if already_joined?
        logger.info { "Host is already joined to the master" }
        return
      end

      logger.info { "Joining host to the master ..." }
      join_command = 'sudo '
      @master_ssh.exec("sudo kubeadm token create --print-join-command") do |type, output|
        join_command << output
      end

      code = @ssh.exec(join_command) do |type, data|
        logger.debug { data }
      end
      if code != 0
        logger.error { "Failed to join host" }
        raise Shokunin::Error, "Failed to join host"
      end
    end
  end
end