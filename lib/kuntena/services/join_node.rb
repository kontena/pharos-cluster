module Kuntena::Services
  class JoinNode

    class Error < StandardError; end
    class AlreadyJoinedError < Error; end

    def initialize(ssh)
      @ssh = ssh
    end

    def already_joined?
      @ssh.exec("[ -e /etc/kubernetes/kubelet.conf ]") == 0
    end

    def join(master_ssh)
      join_command = 'sudo '
      master_ssh.exec("sudo kubeadm token create --print-join-command") do |type, output|
        join_command << output
      end

      @ssh.exec(join_command)
    end
  end
end