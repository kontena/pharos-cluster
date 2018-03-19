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
      config = YAML.load(configmap.data[:MasterConfiguration])
      config['kubernetesVersion'] != "v#{kube_component.version}"
    end

    def install
      cfg = generate_config
      tmp_file = File.join('/tmp', 'kubeadm.cfg.' + SecureRandom.hex(16))
      @ssh.upload(StringIO.new(cfg.to_yaml), tmp_file)

      # Copy etcd certs over if needed
      exec_script('configure-etcd-certs.sh', {
        ca_certificate: File.read(@config.etcd.ca_certificate),
        certificate: File.read(@config.etcd.certificate),
        certificate_key: File.read(@config.etcd.key)

      }) if @config.etcd && @config.etcd.certificate

      logger.info(@master.address) { "Initializing control plane ..." }

      code = @ssh.exec("sudo kubeadm init --config #{tmp_file}") do |type, data|
        remote_output(type, data)
      end
      if code == 0
        logger.info(@master.address) { "Initialization of control plane succeeded!" }
      else
        raise Kupo::Error, "Initialization of control plane failed!"
      end
      @ssh.exec("rm #{tmp_file}")
      @ssh.exec('mkdir -p ~/.kube')
      @ssh.exec('sudo cat /etc/kubernetes/admin.conf > ~/.kube/config')
    end

    def generate_config

      config = {
        'apiVersion' => 'kubeadm.k8s.io/v1alpha1',
        'kind' => 'MasterConfiguration',
        'kubernetesVersion' => kube_component.version,
        'apiServerCertSANs' => [@master.address, @master.private_address].compact.uniq,
        'apiServerExtraArgs' => {
          'feature-gates' => 'PersistentLocalVolumes=true,VolumeScheduling=true,MountPropagation=true'
        },
        'networking' => {
          'serviceSubnet' => @config.network.service_cidr,
          'podSubnet' => @config.network.pod_network_cidr
        }
      }

      if @master.private_address
        config['api'] = {'advertiseAddress' => @master.private_address}
      else
        config['api'] = {'advertiseAddress' => @master.address}
      end

      if @master.container_runtime == 'cri-o'
        config['criSocket'] = '/var/run/crio/crio.sock'
      end

      # Only configure etcd if the external endpoints are given
      if @config.etcd && @config.etcd.endpoints
        config['etcd'] = {
          'endpoints' => @config.etcd.endpoints
        }

        config['etcd']['certFile'] = '/etc/kupo/etcd/certificate.pem' if @config.etcd.certificate
        config['etcd']['caFile'] = '/etc/kupo/etcd/ca-certificate.pem' if @config.etcd.ca_certificate
        config['etcd']['keyFile'] = '/etc/kupo/etcd/certificate-key.pem' if @config.etcd.key
      end
      config
    end


    def upgrade
      code = @ssh.exec("sudo kubeadm upgrade apply #{kube_component.version} -y") do |type, data|
        remote_output(type, data)
      end

      if code == 0
        logger.info(@master.address) { "Control plane upgrade succeeded!" }
      else
        raise Kupo::Error, "Control plane upgrade failed!"
      end
    end

    def kube_component
      @kube_component ||= self.class.components.find { |c| c.name == 'kubernetes' }
    end
  end
end
