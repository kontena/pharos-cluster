# frozen_string_literal: true

module Pharos
  module Kubeadm
    class ClusterConfig
      PHAROS_DIR = Pharos::Kubeadm::PHAROS_DIR
      CA_FILE = '/etc/kubernetes/pki/ca.crt'
      AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR = '/etc/kubernetes/authentication'
      OIDC_CONFIG_DIR = '/etc/kubernetes/authentication'
      AUDIT_CFG_DIR = (PHAROS_DIR + '/audit').freeze
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze
      CLOUD_CFG_DIR = (PHAROS_DIR + '/cloud').freeze
      CLOUD_CFG_FILE = (CLOUD_CFG_DIR + '/cloud-config').freeze
      DEFAULT_ADMISSION_PLUGINS = %w(PodSecurityPolicy NodeRestriction AlwaysPullImages NamespaceLifecycle ServiceAccount).freeze
      # CIS compliat TLS ciphers
      TLS_CIPHERS = 'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256'

      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
      end

      # @return [Hash]
      def generate
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1beta1',
          'kind' => 'ClusterConfiguration',
          'kubernetesVersion' => Pharos::KUBE_VERSION,
          'clusterName' => @config.name,
          'imageRepository' => @config.image_repository,
          'networking' => {
            'serviceSubnet' => @config.network.service_cidr,
            'podSubnet' => @config.network.pod_network_cidr
          },
          'apiServer' => {
            'extraArgs' => {
              'profiling' => 'false', # CIS 1.1.8
              'kubelet-certificate-authority' => CA_FILE,
              'repair-malformed-updates' => 'false', # CIS 1.1.9
              'tls-cipher-suites' => TLS_CIPHERS, # CIS 1.1.30
              'service-account-lookup' => 'true' # CIS 1.1.23
            },
            'certSANs' => build_extra_sans
          },
          'controlPlaneEndpoint' => 'localhost:6443', # client-side loadbalanced kubelets
          'controllerManager' => {
            'extraArgs' => {
              'horizontal-pod-autoscaler-use-rest-clients' => 'true',
              'profiling' => 'false', # CIS 1.2.1
              'terminated-pod-gc-threshold' => '1000' # CIS 1.3.1
            }
          },
          'scheduler' => {
            'extraArgs' => {
              'profiling' => 'false' # CIS 1.3.2
            }
          }
        }

        if @config.api&.feature_gates
          feature_gates = @config.api.feature_gates.map{ |k, v| "#{k}=#{v}" }.join(',')
          config['apiServer']['extraArgs']['feature-gates'] = feature_gates
          config['scheduler']['extraArgs']['feature-gates'] = feature_gates
          config['controllerManager']['extraArgs']['feature-gates'] = feature_gates
        end

        if @config.cloud && @config.cloud.provider != 'external'
          config['apiServer']['extraArgs']['cloud-provider'] = @config.cloud.provider
          config['controllerManager']['extraArgs']['cloud-provider'] = @config.cloud.provider
          if @config.cloud.config
            config['apiServer']['extraArgs']['cloud-config'] = CLOUD_CFG_FILE
            config['controllerManager']['extraArgs']['cloud-config'] = CLOUD_CFG_FILE
          end
        end

        # Only configure etcd if the external endpoints are given
        if @config.etcd&.endpoints
          configure_external_etcd(config)
        else
          configure_internal_etcd(config)
        end
        config['apiServer']['extraVolumes'] = [
          {
            'name' => 'pharos',
            'hostPath' => PHAROS_DIR,
            'mountPath' => PHAROS_DIR
          }
        ]

        config['controllerManager']['extraVolumes'] = [
          {
            'name' => 'pharos',
            'hostPath' => PHAROS_DIR,
            'mountPath' => PHAROS_DIR
          }
        ]

        # Only if authentication token webhook option are given
        configure_token_webhook(config) if @config.authentication&.token_webhook
        # Only if authentication oidc options are given
        configure_oidc(config) if @config.authentication&.oidc

        # Configure audit related things if needed
        configure_audit_webhook(config) if @config.audit&.webhook&.server
        configure_audit_file(config) if @config.audit&.file

        configure_admission_plugins(config)

        # Set secrets config location and mount it to api server
        config['apiServer']['extraArgs']['experimental-encryption-provider-config'] = SECRETS_CFG_FILE
        config['apiServer']['extraVolumes'] << {
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

      # @param config [Pharos::Config]
      def configure_internal_etcd(config)
        config['etcd'] = {
          'external' => {
            'endpoints' => @config.etcd_hosts.map { |h|
              "https://#{@config.etcd_peer_address(h)}:2379"
            },
            'certFile' => '/etc/pharos/pki/etcd/client.pem',
            'caFile' => '/etc/pharos/pki/ca.pem',
            'keyFile' => '/etc/pharos/pki/etcd/client-key.pem'
          }
        }
      end

      # @param config [Hash]
      def configure_external_etcd(config)
        config['etcd'] = {
          'external' => {
            'endpoints' => @config.etcd.endpoints
          }
        }

        config['etcd']['external']['certFile'] = '/etc/pharos/etcd/certificate.pem' if @config.etcd.certificate
        config['etcd']['external']['caFile'] = '/etc/pharos/etcd/ca-certificate.pem' if @config.etcd.ca_certificate
        config['etcd']['external']['keyFile'] = '/etc/pharos/etcd/certificate-key.pem' if @config.etcd.key
      end

      # @param config [Hash]
      def configure_token_webhook(config)
        config['apiServer']['extraArgs'].merge!(authentication_token_webhook_args(@config.authentication.token_webhook.cache_ttl))
        config['apiServer']['extraVolumes'] += volume_mounts_for_authentication_token_webhook
      end

      # @param config [Hash]
      def configure_audit_webhook(config)
        config['apiServer']['extraArgs'].merge!(
          "audit-webhook-config-file" => AUDIT_CFG_DIR + '/webhook.yml',
          "audit-policy-file" => AUDIT_CFG_DIR + '/policy.yml'
        )
        config['apiServer']['extraVolumes'] += volume_mounts_for_audit_config
      end

      # @param config [Hash]
      def configure_oidc(config)
        config['apiServer']['extraArgs'].merge!(
          'oidc-issuer-url' => @config.authentication.oidc.issuer_url,
          'oidc-client-id' => @config.authentication.oidc.client_id
        )
        # These are optional in config, so set conditionally
        config['apiServer']['extraArgs']['oidc-username-claim'] = @config.authentication.oidc.username_claim if @config.authentication.oidc.username_claim
        config['apiServer']['extraArgs']['oidc-username-prefix'] = @config.authentication.oidc.username_prefix if @config.authentication.oidc.username_prefix
        config['apiServer']['extraArgs']['oidc-groups-claim'] = @config.authentication.oidc.groups_claim if @config.authentication.oidc.groups_claim
        config['apiServer']['extraArgs']['oidc-groups-prefix'] = @config.authentication.oidc.groups_prefix if @config.authentication.oidc.groups_prefix
        config['apiServer']['extraArgs']['oidc-ca-file'] = OIDC_CONFIG_DIR + '/oidc_ca.crt' if @config.authentication.oidc.ca_file

        config['apiServer']['extraVolumes'] += volume_mounts_for_authentication_oidc if @config.authentication.oidc.ca_file
      end

      # @return [Array<Hash>]
      def volume_mounts_for_audit_config
        volume_mounts = []
        volume_mount = {
          'name' => 'k8s-audit-webhook',
          'hostPath' => AUDIT_CFG_DIR,
          'mountPath' => AUDIT_CFG_DIR
        }
        volume_mounts << volume_mount

        volume_mounts
      end

      # @param cache_ttl [String]
      def authentication_token_webhook_args(cache_ttl = nil)
        config = {
          'authentication-token-webhook-config-file' => AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR + '/token-webhook-config.yaml'
        }
        config['authentication-token-webhook-cache-ttl'] = cache_ttl if cache_ttl
        config
      end

      # @return [Array<Hash>]
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

      def volume_mounts_for_authentication_oidc
        volume_mounts = []
        volume_mount = {
          'name' => 'k8s-auth-oidc',
          'hostPath' => OIDC_CONFIG_DIR,
          'mountPath' => OIDC_CONFIG_DIR
        }
        volume_mounts << volume_mount
        volume_mounts
      end

      # @param config [Hash]
      def configure_audit_file(config)
        config['apiServer']['extraArgs'].merge!(
          "audit-log-path" => @config.audit.file.path,
          "audit-log-maxage" => @config.audit.file.max_age.to_s,
          "audit-log-maxbackup" => @config.audit.file.max_backups.to_s,
          "audit-log-maxsize" => @config.audit.file.max_size.to_s,
          "audit-policy-file" => AUDIT_CFG_DIR + '/policy.yml'
        )
        base_dir = File.dirname(@config.audit.file.path)
        config['apiServer']['extraVolumes'] += [{
          'name' => 'k8s-audit-file',
          'hostPath' => base_dir,
          'mountPath' => base_dir,
          'readOnly' => false
        }]
        config['apiServer']['extraVolumes'] += volume_mounts_for_audit_config
      end

      # @param config [Hash]
      def configure_admission_plugins(config)
        disabled_plugins = @config.admission_plugins&.reject(&:enabled)&.map(&:name) || []
        enabled_plugins = DEFAULT_ADMISSION_PLUGINS.reject{ |p| disabled_plugins.include?(p) } + (@config.admission_plugins&.select(&:enabled)&.map(&:name) || [])

        config['apiServer']['extraArgs']['enable-admission-plugins'] = enabled_plugins.uniq.join(',') unless enabled_plugins.empty?
        config['apiServer']['extraArgs']['disable-admission-plugins'] = disabled_plugins.uniq.join(',') unless disabled_plugins.empty?
      end
    end
  end
end
