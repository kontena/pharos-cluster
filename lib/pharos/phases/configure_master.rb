# frozen_string_literal: true

require "base64"

module Pharos
  module Phases
    class ConfigureMaster < Pharos::Phase
      title "Configure master"

      KUBE_DIR = '/etc/kubernetes'
      PHAROS_DIR = '/etc/pharos'
      SHARED_CERT_FILES = %w(ca.crt ca.key sa.key sa.pub).freeze
      AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR = '/etc/kubernetes/authentication'
      AUDIT_CFG_DIR = (PHAROS_DIR + '/audit').freeze
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze
      CLOUD_CFG_DIR = (PHAROS_DIR + '/cloud').freeze
      CLOUD_CFG_FILE = (CLOUD_CFG_DIR + '/cloud-config').freeze

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
        manifest = File.join(KUBE_DIR, 'manifests', 'kube-apiserver.yaml')
        file = @ssh.file(manifest)
        return false unless file.exist?
        return false if file.read.match?(/kube-apiserver-.+:v#{Pharos::KUBE_VERSION}/)

        true
      end

      def install
        configure_kubelet
        cfg = generate_config
        push_configs
        copy_kube_certs

        logger.info { "Initializing control plane ..." }

        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm init --ignore-preflight-errors all --skip-token-print --config #{tmp_file}")
        end

        cache_kube_certs

        logger.info { "Initialization of control plane succeeded!" }
        @ssh.exec!('install -m 0700 -d ~/.kube')
        @ssh.exec!('sudo install -o $USER -m 0600 /etc/kubernetes/admin.conf ~/.kube/config')
      end

      def configure
        copy_kube_certs
        push_configs
        cfg = generate_config
        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm alpha phase controlplane all --config #{tmp_file}")
          @ssh.exec!("sudo kubeadm alpha phase mark-master --config #{tmp_file}")
        end
        cache_kube_certs
        configure_kubelet
      end

      def upgrade
        logger.info { "Upgrading control plane ..." }
        exec_script(
          "install-kubeadm.sh",
          VERSION: Pharos::KUBEADM_VERSION,
          ARCH: @host.cpu_arch.name
        )
        copy_kube_certs
        push_configs
        cfg = generate_config
        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo kubeadm upgrade apply #{Pharos::KUBE_VERSION} -y --ignore-preflight-errors=all --allow-experimental-upgrades --config #{tmp_file}")
        end
        logger.info { "Control plane upgrade succeeded!" }

        cache_kube_certs
        configure_kubelet
      end

      def push_configs
        # Copy etcd certs over if needed
        if @config.etcd&.certificate
          logger.info { "Pushing external etcd certificates ..." }
          copy_external_etcd_certs
        end

        push_cloud_config if @config.cloud&.config
        push_audit_config if @config.audit&.server

        # Generate and upload authentication token webhook config file if needed
        push_authentication_token_webhook_config if @config.authentication&.token_webhook
      end

      def generate_config
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1alpha1',
          'kind' => 'MasterConfiguration',
          'nodeName' => @host.hostname,
          'kubernetesVersion' => Pharos::KUBE_VERSION,
          'api' => {
            'advertiseAddress' => @host.peer_address,
            'controlPlaneEndpoint' => 'localhost'
          },
          'apiServerCertSANs' => build_extra_sans,
          'networking' => {
            'serviceSubnet' => @config.network.service_cidr,
            'podSubnet' => @config.network.pod_network_cidr
          },
          'controllerManagerExtraArgs' => {
            'horizontal-pod-autoscaler-use-rest-clients' => 'false'
          },
          'noTaintMaster' => !!@host.taints && @host.taints.none?{ |taint| taint.key == 'node-role.kubernetes.io/master' && taint.effect == 'NoSchedule' }
        }

        if @host.container_runtime == 'cri-o'
          config['criSocket'] = '/var/run/crio/crio.sock'
        end

        config['apiServerExtraArgs'] = {
          'apiserver-count' => @config.master_hosts.size.to_s
        }

        if @config.cloud && @config.cloud.provider != 'external'
          config['cloudProvider'] = @config.cloud.provider
          if @config.cloud.config
            config['apiServerExtraArgs']['cloud-config'] = CLOUD_CFG_FILE
            config['controllerManagerExtraArgs']['cloud-config'] = CLOUD_CFG_FILE
          end
        end

        # Only configure etcd if the external endpoints are given
        if @config.etcd&.endpoints
          configure_external_etcd(config)
        else
          configure_internal_etcd(config)
        end
        config['apiServerExtraVolumes'] = [
          {
            'name' => 'pharos',
            'hostPath' => PHAROS_DIR,
            'mountPath' => PHAROS_DIR
          }
        ]

        config['controllerManagerExtraVolumes'] = [
          {
            'name' => 'pharos',
            'hostPath' => PHAROS_DIR,
            'mountPath' => PHAROS_DIR
          }
        ]

        # Only if authentication token webhook option are given
        configure_token_webhook(config) if @config.authentication&.token_webhook

        # Configure audit related things if needed
        configure_audit_webhook(config) if @config.audit&.server

        configure_kube_proxy(config) if @config.kube_proxy

        # Set secrets config location and mount it to api server
        config['apiServerExtraArgs']['experimental-encryption-provider-config'] = SECRETS_CFG_FILE
        config['apiServerExtraVolumes'] << {
          'name' => 'k8s-secrets-config',
          'hostPath' => SECRETS_CFG_DIR,
          'mountPath' => SECRETS_CFG_DIR
        }
        config
      end

      # @return [Array<String>]
      def build_extra_sans
        extra_sans = Set.new(['localhost'])
        extra_sans << @host.address
        extra_sans << @host.private_address if @host.private_address
        extra_sans << @host.private_interface_address if @host.private_interface_address
        extra_sans << @host.api_endpoint if @host.api_endpoint

        extra_sans.to_a
      end

      # Copies certificates from memory to host
      def copy_kube_certs
        return unless cluster_context['master-certs']

        @ssh.exec!("sudo mkdir -p #{KUBE_DIR}/pki")
        cluster_context['master-certs'].each do |file, contents|
          path = File.join(KUBE_DIR, 'pki', file)
          @ssh.file(path).write(contents)
          @ssh.exec!("sudo chmod 0400 #{path}")
        end
      end

      # Cache certs to memory
      def cache_kube_certs
        return if cluster_context['master-certs']

        cache = {}
        SHARED_CERT_FILES.each do |file|
          path = File.join(KUBE_DIR, 'pki', file)
          cache[file] = @ssh.file(path).read
        end
        cluster_context['master-certs'] = cache
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
        @ssh.file('/etc/pharos/etcd/ca-certificate.pem').write(File.open(@config.etcd.ca_certificate))
        @ssh.file('/etc/pharos/etcd/certificate.pem').write(File.open(@config.etcd.certificate))
        @ssh.file('/etc/pharos/etcd/certificate-key.pem').write(File.open(@config.etcd.key))
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
      def configure_kube_proxy(config)
        config['kubeProxy'] = {
          'config' => {
            'featureGates' => {}
          }
        }

        if @config.kube_proxy.mode
          config['kubeProxy']['config']['mode'] = @config.kube_proxy.mode
        end

        if @config.kube_proxy.mode == 'ipvs'
          config['kubeProxy']['config']['featureGates']['SupportIPVSProxyMode'] = true
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

      def push_audit_config
        logger.info { "Pushing audit configs to master ..." }
        @ssh.exec!("sudo mkdir -p #{AUDIT_CFG_DIR}")
        @ssh.file("#{AUDIT_CFG_DIR}/webhook.yml").write(
          parse_resource_file('audit/webhook-config.yml.erb', server: @config.audit.server)
        )
        @ssh.file("#{AUDIT_CFG_DIR}/policy.yml").write(parse_resource_file('audit/policy.yml'))
      end

      def push_authentication_token_webhook_config
        webhook_config = @config.authentication.token_webhook.config
        logger.info { "Generating token authentication webhook config ..." }
        auth_token_webhook_config = generate_authentication_token_webhook_config(webhook_config)
        logger.info { "Pushing token authentication webhook config ..." }
        upload_authentication_token_webhook_config(auth_token_webhook_config)
        logger.info { "Pushing token authentication webhook certificates ..." }
        upload_authentication_token_webhook_certs(webhook_config)
      end

      def push_cloud_config
        logger.info { "Pushing cloud-config to master ..." }
        @ssh.exec!('sudo mkdir -p ' + CLOUD_CFG_DIR)
        @ssh.file(CLOUD_CFG_FILE).write(File.open(File.expand_path(@config.cloud.config)))
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
