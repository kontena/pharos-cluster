require_relative 'base'

module Kupo::Phases
  class ConfigureMaster < Base

    # @param master [Kupo::Configuration::Host]
    # @param config [Kupo::Configuration::Network]
    def initialize(master, config)
      @master = master
      @config = config
      @ssh = Kupo::SSH::Client.for_host(@master)
    end

    def call
      logger.info { "Checking if Kubernetes control plane is already initialized ..." }
      if install?
        logger.info { "Kubernetes control plane is not initialized, proceeding to initialize ..." }
        install
      elsif upgrade?
        logger.info { "Upgrading Kubernetes control plane ..." }
        upgrade
      else
        logger.info { "Kubernetes control plane is up-to-date." }
      end
    end

    def install?
      !@ssh.file_exists?("/etc/kubernetes/admin.conf")
    end

    def upgrade?
      return false unless Kupo::Kube.config_exists?(@master.address)

      client = Kupo::Kube.client(@master.address)
      configmap = client.get_config_map('kubeadm-config', 'kube-system')
      kube_version = self.class.components.find {|c| c.name == 'kubernetes' }
      config = YAML.load(configmap.data[:MasterConfiguration])
      config['kubernetesVersion'] != "v#{kube_version.version}"
    end

    def install
      sans = [@master.address, @master.private_address].compact.uniq
      options = [
        "--apiserver-cert-extra-sans #{sans.join(',')}",
        "--service-cidr #{@config.service_cidr}",
        "--pod-network-cidr #{@config.pod_network_cidr}"
      ]
      if @master.private_address
        options << "--apiserver-advertise-address #{@master.private_address}"
      else
        options << "--apiserver-advertise-address #{@master.address}"
      end
      logger.info(@master.address) { "Initializing control plane ..." }
      code = @ssh.exec("sudo kubeadm init #{options.join(' ')}") do |type, data|
        remote_output(type, data)
      end
      if code == 0
        logger.info(@master.address) { "Initialization of control plane succeeded!" }
      else
        raise Kupo::Error, "Initialization of control plane failed!"
      end

      @ssh.exec('mkdir -p ~/.kube')
      @ssh.exec('sudo cat /etc/kubernetes/admin.conf > ~/.kube/config')
    end

    def upgrade
      @ssh.exec("sudo kubeadm upgrade apply #{Kupo::KUBE_VERSION} -y") do |type, data|
        remote_output(type, data)
      end
    end
  end
end
