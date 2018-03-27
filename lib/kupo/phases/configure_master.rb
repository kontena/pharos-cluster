# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ConfigureMaster < Base
      # @param master [Kupo::Configuration::Host]
      # @param config [Kupo::Configuration::Network]
      def initialize(master, config)
        @master = master
        @config = config
        @ssh = Kupo::SSH::Client.for_host(@master)
      end

      def client
        @client ||= Kupo::Kube.client(@master.address)
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

        kubeadm_configmap['kubernetesVersion'] != "v#{Kupo::KUBE_VERSION}"
      end

      # @return [Hash]
      def kubeadm_configmap
        configmap = client.get_config_map('kubeadm-config', 'kube-system')
        YAML.safe_load(configmap.data[:MasterConfiguration])
      end

      def install
        Kupo::Phases::ConfigureKubelet.new(@master).call

        cfg = generate_config

        # Copy etcd certs over if needed
        if @config.etcd&.certificate
          # TODO: lock down permissions on key
          @ssh.exec!('sudo mkdir -p /etc/kupo/etcd')
          @ssh.write_file('/etc/kupo/etcd/ca-certificate.pem', File.read(@config.etcd.ca_certificate))
          @ssh.write_file('/etc/kupo/etcd/certificate.pem', File.read(@config.etcd.certificate))
          @ssh.write_file('/etc/kupo/etcd/certificate-key.pem', File.read(@config.etcd.key))
        end

        logger.info(@master.address) { "Initializing control plane ..." }

        @ssh.with_tmpfile(cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm init --config #{tmp_file}")
        end

        logger.info(@master.address) { "Initialization of control plane succeeded!" }

        @ssh.exec!('mkdir -p ~/.kube')
        @ssh.exec!('sudo cat /etc/kubernetes/admin.conf > ~/.kube/config')
      end

      def generate_config
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1alpha1',
          'kind' => 'MasterConfiguration',
          'kubernetesVersion' => Kupo::KUBE_VERSION,
          'apiServerCertSANs' => [@master.address, @master.private_address].compact.uniq,
          'networking' => {
            'serviceSubnet' => @config.network.service_cidr,
            'podSubnet' => @config.network.pod_network_cidr
          }
        }

        config['api'] = { 'advertiseAddress' => @master.private_address || @master.address }

        if @master.container_runtime == 'cri-o'
          config['criSocket'] = '/var/run/crio/crio.sock'
        end

        # Only configure etcd if the external endpoints are given
        if @config.etcd&.endpoints
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
        logger.info(@master.address) { "Upgrading control plane ..." }
        exec_script("install-kubeadm.sh",
                    VERSION: Kupo::KUBEADM_VERSION,
                    ARCH: @master.cpu_arch.name)

        cfg = generate_config
        @ssh.with_tmpfile(cfg.to_yaml) do |tmp_file|
          @ssh.exec!("sudo kubeadm upgrade apply #{Kupo::KUBE_VERSION} -y --allow-experimental-upgrades --config #{tmp_file}")
        end
        logger.info(@master.address) { "Control plane upgrade succeeded!" }

        Kupo::Phases::ConfigureKubelet.new(@master).call
      end
    end
  end
end
