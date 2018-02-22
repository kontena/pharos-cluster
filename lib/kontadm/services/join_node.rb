module Kontadm::Services
  class JoinNode

    def initialize(host, master)
      @host = host
      @master = master
      @ssh = Kontadm::SSH::Client.for_host(@host)
      @master_ssh = Kontadm::SSH::Client.for_host(@master)
    end

    def already_joined?
      @ssh.exec("[ -e /etc/kubernetes/kubelet.conf ]") == 0
    end

    def call
      return if already_joined?

      join_command = 'sudo '
      @master_ssh.exec("sudo kubeadm token create --print-join-command") do |type, output|
        join_command << output
      end

      @ssh.exec(join_command)
    end
  end
end