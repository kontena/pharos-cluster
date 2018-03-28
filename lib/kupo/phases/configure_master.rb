# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ConfigureMaster < Base
      PHAROS_DIR = '/etc/pharos'
      AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR = '/etc/kubernetes/authentication'

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
        config = YAML.safe_load(configmap.data[:MasterConfiguration])
        config['kubernetesVersion'] != "v#{kube_component.version}"
      end

      def install
        cfg = generate_config

        # Copy etcd certs over if needed
        if @config.etcd&.certificate
          # TODO: lock down permissions on key
          @ssh.exec!('sudo mkdir -p /etc/kupo/etcd')
          @ssh.write_file('/etc/kupo/etcd/ca-certificate.pem', File.read(@config.etcd.ca_certificate))
          @ssh.write_file('/etc/kupo/etcd/certificate.pem', File.read(@config.etcd.certificate))
          @ssh.write_file('/etc/kupo/etcd/certificate-key.pem', File.read(@config.etcd.key))
        end

        # Generate and upload authentication token webhook config file if needed
        if @config.authentication&.token_webhook
          webhook_config = @config.authentication.token_webhook.config
          auth_token_webhook_config = generate_authentication_token_webhook_config(webhook_config)
          upload_authentication_token_webhook_config(auth_token_webhook_config)
          upload_authentication_token_webhook_certs(webhook_config)
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
          'kubernetesVersion' => kube_component.version,
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

        config['apiServerExtraArgs'] = {}
        config['apiServerExtraVolumes'] = []

        # Only if authentication token webhook option are given
        if @config.authentication&.token_webhook
          config['apiServerExtraArgs'].merge!(authentication_token_webhook_args(@config.authentication.token_webhook.cache_ttl))
          config['apiServerExtraVolumes'] += volume_mounts_for_authentication_token_webhook
        end

        config
      end

      def authentication_token_webhook_args(cache_ttl = nil)
        config = {
          'authentication-token-webhook-config-file' => AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR + '/token-webhook-config.yaml'
        }
        config['authentication-token-webhook-cache-ttl'] = cache_ttl if cache_ttl
        config
      end

      def volume_mounts_for_authentication_token_webhook
        volume_mounts = []
        volume_mount = {
          'name' => 'k8s-auth-token-webhook',
          'hostPath' => AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR,
          'mountPath' => AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR
        }
        volume_mounts << volume_mount
        pharos_volume_mount = {
          'name' => 'pharos',
          'hostPath' => PHAROS_DIR,
          'mountPath' => PHAROS_DIR
        }
        volume_mounts << pharos_volume_mount
        volume_mounts
      end

      def generate_authentication_token_webhook_config(webhook_config)
        config = {
          "kind" => "Config",
          "apiVersion" => "v1",
          "preferences" => {},
          "clusters" => [
            {
              "name" => webhook_config[:cluster][:name].to_s,
              "cluster" => {
                "server" => webhook_config[:cluster][:server].to_s
              }
            }
          ],
          "users" => [
            {
              "name" => webhook_config[:user][:name].to_s,
              "user" => {}
            }
          ],
          "contexts" => [
            {
              "name" => "webhook",
              "context" => {
                "cluster" => webhook_config[:cluster][:name].to_s,
                "user" => webhook_config[:user][:name].to_s
              }
            }
          ],
          "current-context" => "webhook"
        }

        if webhook_config[:cluster][:certificate_authority]
          config["clusters"][0]["cluster"]["certificate-authority"] = PHAROS_DIR + "/token_webhook/ca.pem"
        end

        if webhook_config[:user][:client_certificate]
          config["users"][0]["user"]["client-certificate"] = PHAROS_DIR + "/token_webhook/cert.pem"
        end

        if webhook_config[:user][:client_key]
          config["users"][0]["user"]["client-key"] = PHAROS_DIR + "/token_webhook/key.pem"
        end

        config
      end

      def upload_authentication_token_webhook_config(config)
        filename = 'token-webhook-config.yaml'
        @ssh.exec!("sudo mkdir -p #{AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR}")
        @ssh.upload(StringIO.new(config.to_yaml), "/tmp/#{filename}")
        @ssh.exec!("sudo mv /tmp/#{filename} #{AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR}")
      end

      def upload_authentication_token_webhook_certs(webhook_config)
        @ssh.exec!("sudo mkdir -p #{PHAROS_DIR}/token_webhook")
        @ssh.write_file(PHAROS_DIR + '/token_webhook/ca.pem', File.read(File.expand_path(webhook_config[:cluster][:certificate_authority]))) if webhook_config[:cluster][:certificate_authority]
        @ssh.write_file(PHAROS_DIR + '/token_webhook/cert.pem', File.read(File.expand_path(webhook_config[:user][:client_certificate]))) if webhook_config[:user][:client_certificate]
        @ssh.write_file(PHAROS_DIR + '/token_webhook/key.pem', File.read(File.expand_path(webhook_config[:user][:client_key]))) if webhook_config[:user][:client_key]
      end

      def upgrade
        @ssh.exec!("sudo kubeadm upgrade apply #{kube_component.version} -y")

        logger.info(@master.address) { "Control plane upgrade succeeded!" }
      end

      def kube_component
        @kube_component ||= Kupo::Phases.find_component(name: 'kubernetes')
      end
    end
  end
end
