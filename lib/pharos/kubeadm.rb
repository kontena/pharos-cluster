# frozen_string_literal: true

module Pharos
  class Kubeadm
    class ConfigGenerator
      PHAROS_DIR = '/etc/pharos'
      AUTHENTICATION_TOKEN_WEBHOOK_CONFIG_DIR = '/etc/kubernetes/authentication'
      AUDIT_CFG_DIR = (PHAROS_DIR + '/audit').freeze
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze
      CLOUD_CFG_DIR = (PHAROS_DIR + '/cloud').freeze
      CLOUD_CFG_FILE = (CLOUD_CFG_DIR + '/cloud-config').freeze

      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
      end

      # @return [Hash]
      def generate_config
        config = {
          'apiVersion' => 'kubeadm.k8s.io/v1alpha2',
          'kind' => 'MasterConfiguration',

          'nodeRegistration' => {
            'name' => @host.hostname
          },
          'kubernetesVersion' => Pharos::KUBE_VERSION,
          'imageRepository' => @config.image_repository,
          'api' => {
            'advertiseAddress' => @host.peer_address,
            'controlPlaneEndpoint' => 'localhost'
          },
          'apiServerCertSANs' => build_extra_sans,
          'networking' => {
            'serviceSubnet' => @config.network.service_cidr,
            'podSubnet' => @config.network.pod_network_cidr
          },
          'apiServerExtraArgs' => {},
          'controllerManagerExtraArgs' => {
            'horizontal-pod-autoscaler-use-rest-clients' => 'true'
          }
        }

        unless master_taint?
          config['nodeRegistration']['taints'] = []
        end

        if @host.container_runtime == 'cri-o'
          config['nodeRegistration']['criSocket'] = '/var/run/crio/crio.sock'
        end

        if @config.cloud && @config.cloud.provider != 'external'
          config['apiServerExtraArgs']['cloud-provider'] = @config.cloud.provider
          config['controllerManagerExtraArgs']['cloud-provider'] = @config.cloud.provider
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

        configure_admission_plugins(config) if @config.admission_plugins

        # Set secrets config location and mount it to api server
        config['apiServerExtraArgs']['experimental-encryption-provider-config'] = SECRETS_CFG_FILE
        config['apiServerExtraVolumes'] << {
          'name' => 'k8s-secrets-config',
          'hostPath' => SECRETS_CFG_DIR,
          'mountPath' => SECRETS_CFG_DIR
        }
        config
      end

      def master_taint?
        return true unless @host.taints

        # matching the taint used by kubeadm
        @host.taints.any?{ |taint| taint.key == 'node-role.kubernetes.io/master' && taint.effect == 'NoSchedule' }
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
              "https://#{h.peer_address}:2379"
            },
            'certFile'  => '/etc/pharos/pki/etcd/client.pem',
            'caFile'    => '/etc/pharos/pki/ca.pem',
            'keyFile'   => '/etc/pharos/pki/etcd/client-key.pem'
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

      # @param config [Hash]
      def configure_kube_proxy(config)
        config['kubeProxy'] = {
          'config' => {}
        }

        if @config.kube_proxy.mode
          config['kubeProxy']['config']['mode'] = @config.kube_proxy.mode
        end

        config
      end

      # Generate config contents for kube-apiserver --audit-webhook-config-file
      #
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

      def configure_admission_plugins(config)
        enabled_plugins = @config.admission_plugins.select(&:enabled).map(&:name)
        disabled_plugins = @config.admission_plugins.reject(&:enabled).map(&:name)

        config['apiServerExtraArgs']['enable-admission-plugins'] = enabled_plugins.join(',') unless enabled_plugins.empty?
        config['apiServerExtraArgs']['disable-admission-plugins'] = disabled_plugins.join(',') unless disabled_plugins.empty?
      end
    end
  end
end
