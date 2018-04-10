# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMaster < Pharos::Phase
      title "Configure master"
      KUBE_DIR = '/etc/kubernetes'
      PHAROS_DIR = '/etc/pharos'
      AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR = '/etc/kubernetes/authentication'

      AUDIT_CFG_DIR = (PHAROS_DIR + '/audit').freeze

      def client
        @client ||= Pharos::Kube.client(@host.address)
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
          configure
        end
      end

      def install?
        !@ssh.file("/etc/kubernetes/admin.conf").exist?
      end

      def upgrade?
        return false unless Pharos::Kube.config_exists?(@host.address)

        kubeadm_configmap['kubernetesVersion'] != "v#{Pharos::KUBE_VERSION}"
      end

      def leader?
        @config.master_leader == @master
      end

      # @return [Hash]
      def kubeadm_configmap
        configmap = client.get_config_map('kubeadm-config', 'kube-system')
        Pharos::YamlFile.new(StringIO.new(configmap.data[:MasterConfiguration])).load
      end

      def install
        configure_kubelet

        cfg = generate_config

        # Copy etcd certs over if needed
        if @config.etcd&.certificate
          logger.info(@host.address) { "Pushing external etcd certificates ..." }
          copy_external_etcd_certs
        end

        logger.info(@master.address) { "Pushing etcd certificates ..." }
        copy_internal_etcd_certs

        if @config.audit&.server
          logger.info(@master.address) { "Pushing audit configs to master ..." }
          @ssh.exec!("sudo mkdir -p #{AUDIT_CFG_DIR}")
          @ssh.file("#{AUDIT_CFG_DIR}/webhook.yml").write(
            parse_resource_file('audit/webhook-config.yml.erb', server: @config.audit.server)
          )
          @ssh.file("#{AUDIT_CFG_DIR}/policy.yml").write(parse_resource_file('audit/policy.yml'))
        end

        # Generate and upload authentication token webhook config file if needed
        if @config.authentication&.token_webhook
          webhook_config = @config.authentication.token_webhook.config
          logger.info(@master.address) { "Generating token authentication webhook config ..." }
          auth_token_webhook_config = generate_authentication_token_webhook_config(webhook_config)
          logger.info(@master.address) { "Pushing token authentication webhook config ..." }
          upload_authentication_token_webhook_config(auth_token_webhook_config)
          logger.info(@master.address) { "Pushing token authentication webhook certificates ..." }
          upload_authentication_token_webhook_certs(webhook_config)
        end

        copy_kube_certs unless leader?

        logger.info { "Initializing control plane ..." }

        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm init --config #{tmp_file}")
        end

        logger.info { "Initialization of control plane succeeded!" }
        @ssh.exec!('install -m 0700 -d ~/.kube')
        @ssh.exec!('sudo install -o $USER -m 0600 /etc/kubernetes/admin.conf ~/.kube/config')
      end

      def generate_config
        extra_sans = Set.new
        @config.master_hosts.each do |h|
          extra_sans += [h.address, h.private_address].compact.uniq
        end
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1alpha1',
          'kind' => 'MasterConfiguration',
          'kubernetesVersion' => Pharos::KUBE_VERSION,
          'apiServerCertSANs' => extra_sans.to_a,
          'networking' => {
            'serviceSubnet' => @config.network.service_cidr,
            'podSubnet' => @config.network.pod_network_cidr
          }
        }

        config['api'] = { 'advertiseAddress' => @host.peer_address }

        if @host.container_runtime == 'cri-o'
          config['criSocket'] = '/var/run/crio/crio.sock'
        end

        if @config.cloud && @config.cloud.provider != 'external'
          config['cloudProvider'] = @config.cloud.provider
        end

        # Only configure etcd if the external endpoints are given
        if @config.etcd&.endpoints
          configure_external_etcd(config)
        else
          configure_internal_etcd(config)
        end

        config['apiServerExtraArgs'] = {}
        config['apiServerExtraVolumes'] = []

        # Only if authentication token webhook option are given
        configure_token_webhook(config) if @config.authentication&.token_webhook

        # Configure audit related things if needed
        configure_audit_webhook(config) if @config.audit&.server

        config
      end

      # Copies certificates from leading master
      def copy_kube_certs
        leader = @config.master_leader
        leader_ssh = Pharos::SSH::Client.for_host(leader)
        @ssh.exec!("sudo mkdir -p #{KUBE_DIR}/pki")
        %w(ca.crt ca.key sa.key sa.pub).each do |file|
          path = File.join(KUBE_DIR, 'pki', file)
          contents = leader_ssh.file(path).read
          @ssh.file(path).write(contents)
          @ssh.exec!("sudo chmod 0400 #{path}")
        end
      end

      # @param config [Pharos::Config]
      def configure_internal_etcd(config)
        endpoints = @config.etcd_hosts.map { |h|
          "https://#{h.peer_address}:2379"
        }
        config['etcd'] = {
          'endpoints' => endpoints
        }

        config['etcd']['certFile'] = '/etc/pharos/pki/etcd/client.pem'
        config['etcd']['caFile'] = '/etc/pharos/pki/ca.pem'
        config['etcd']['keyFile'] = '/etc/pharos/pki/etcd/client-key.pem'
      end

      # TODO: lock down permissions on key
      def copy_external_etcd_certs
        @ssh.exec!('sudo mkdir -p /etc/pharos/etcd')
        @ssh.write_file('/etc/pharos/etcd/ca-certificate.pem', File.read(@config.etcd.ca_certificate))
        @ssh.write_file('/etc/pharos/etcd/certificate.pem', File.read(@config.etcd.certificate))
        @ssh.write_file('/etc/pharos/etcd/certificate-key.pem', File.read(@config.etcd.key))
      end

      def copy_internal_etcd_certs
        @ssh.exec!('sudo mkdir -p /etc/pharos/pki/etcd')
        return if @ssh.file('/etc/pharos/pki/etcd/client.pem').exist?

        etcd_peer = @config.etcd_hosts[0]
        etcd_ssh = Pharos::SSH::Client.for_host(etcd_peer)
        @ssh.exec!('sudo mkdir -p /etc/pharos/pki/etcd')
        %w(ca.pem etcd/client.pem etcd/client-key.pem).each do |filename|
          path = "/etc/pharos/pki/#{filename}"
          contents = etcd_ssh.file(path).read
          @ssh.file(path).write(contents)
        end
      end

      # @param config [Hash]
      def configure_external_etcd(config)
        config['etcd'] = {
          'endpoints' => @config.etcd.endpoints
        }

        config['etcd']['certFile'] = '/etc/pharos/etcd/certificate.pem' if @config.etcd.certificate
        config['etcd']['caFile'] = '/etc/pharos/etcd/ca-certificate.pem' if @config.etcd.ca_certificate
        config['etcd']['keyFile'] = '/etc/pharos/etcd/certificate-key.pem' if @config.etcd.key
      end

      # @param config [Hash]
      def configure_token_webhook(config)
        config['apiServerExtraArgs'].merge!(authentication_token_webhook_args(@config.authentication.token_webhook.cache_ttl))
        config['apiServerExtraVolumes'] += volume_mounts_for_authentication_token_webhook
      end

      # @param config [Hash]
      def configure_audit_webhook(config)
        config['apiServerExtraArgs'].merge!(
          "audit-webhook-config-file" => AUDIT_CFG_DIR + '/webhook.yml',
          "audit-policy-file" => AUDIT_CFG_DIR + '/policy.yml'
        )
        config['apiServerExtraVolumes'] += volume_mounts_for_audit_webhook
      end

      def volume_mounts_for_audit_webhook
        volume_mounts = []
        volume_mount = {
          'name' => 'k8s-audit-webhook',
          'hostPath' => AUDIT_CFG_DIR,
          'mountPath' => AUDIT_CFG_DIR
        }
        volume_mounts << volume_mount

        volume_mounts
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

      # @param webhook_config [Hash]
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
          config['clusters'][0]['cluster']['certificate-authority'] = PHAROS_DIR + '/token_webhook/ca.pem'
        end

        if webhook_config[:user][:client_certificate]
          config['users'][0]['user']['client-certificate'] = PHAROS_DIR + '/token_webhook/cert.pem'
        end

        if webhook_config[:user][:client_key]
          config['users'][0]['user']['client-key'] = PHAROS_DIR + '/token_webhook/key.pem'
        end

        config
      end

      # @param config [Hash]
      def upload_authentication_token_webhook_config(config)
        @ssh.exec!('sudo mkdir -p ' + AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR)
        @ssh.file(AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR + '/token-webhook-config.yaml').write(config.to_yaml)
      end

      # @param webhook_config [Hash]
      def upload_authentication_token_webhook_certs(webhook_config)
        @ssh.exec!("sudo mkdir -p #{PHAROS_DIR}/token_webhook")
        @ssh.file(PHAROS_DIR + '/token_webhook/ca.pem').write(File.open(File.expand_path(webhook_config[:cluster][:certificate_authority]))) if webhook_config[:cluster][:certificate_authority]
        @ssh.file(PHAROS_DIR + '/token_webhook/cert.pem').write(File.open(File.expand_path(webhook_config[:user][:client_certificate]))) if webhook_config[:user][:client_certificate]
        @ssh.file(PHAROS_DIR + '/token_webhook/key.pem').write(File.open(File.expand_path(webhook_config[:user][:client_key]))) if webhook_config[:user][:client_key]
      end

      def upgrade
        logger.info { "Upgrading control plane ..." }
        exec_script(
          "install-kubeadm.sh",
          VERSION: Pharos::KUBEADM_VERSION,
          ARCH: @host.cpu_arch.name
        )

        cfg = generate_config
        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm upgrade apply #{Pharos::KUBE_VERSION} -y --allow-experimental-upgrades --config #{tmp_file}")
        end
        logger.info { "Control plane upgrade succeeded!" }

        configure_kubelet
      end

      def configure
        configure_kubelet
      end

      def configure_kubelet
        phase = Pharos::Phases::ConfigureKubelet.new(
          @host,
          config: @config,
          ssh: @ssh
        )
        phase.call
      end
    end
  end
end
