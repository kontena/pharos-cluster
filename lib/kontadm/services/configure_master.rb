module Kontadm::Services
  class ConfigureMaster

    def initialize(master)
      @master = master
    end

    def call
      ssh = Kontadm::SSH::Client.for_host(@master)
      ssh.exec("sudo kubeadm init --apiserver-cert-extra-sans #{@master.address}")
      ssh.exec('mkdir -p ~/.kube')
      ssh.exec('sudo cat /etc/kubernetes/admin.conf > ~/.kube/config')
    end
  end
end