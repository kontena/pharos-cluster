# frozen_string_literal: true

require_relative 'init_config'
require_relative 'cluster_config'
require_relative 'kubeproxy_config'

module Pharos
  module Kubeadm
    class ConfigGenerator
      PHAROS_DIR = Pharos::Kubeadm::PHAROS_DIR

      attr_reader :init_config, :cluster_config, :kubeproxy_config

      # @param config [Pharos::Config] cluster config
      # @param host [Pharos::Configuration::Host] master host-specific config
      def initialize(config, host)
        @config = config
        @host = host
        @init_config = InitConfig.new(config, host)
        @cluster_config = ClusterConfig.new(config, host)
        @kubeproxy_config = KubeProxyConfig.new(config, host)
      end

      # @return [Array<Hash>]
      def generate_config
        [init_config.generate, cluster_config.generate, kubeproxy_config.generate]
      end

      # @return [String]
      def generate_yaml_config
         YAML.dump_stream(*generate_config)
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
    end
  end
end
