module Kuntena::Services
  class ConfigureMaster

    def initialize(ssh, host: )
      @ssh = ssh
      @host = host
    end

    def call
      @ssh.exec("sudo kubeadm init --apiserver-cert-extra-sans #{@host}")
      @ssh.exec('mkdir -p ~/.kube')
      @ssh.exec('sudo cat /etc/kubernetes/admin.conf > ~/.kube/config')
    end
  end
end