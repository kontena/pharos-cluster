# frozen_string_literal: true

require 'fugit'
require 'dry-validation'

module Pharos
  class ConfigSchema
    DEFAULT_DATA = {
      'hosts' => [],
      'api' => {},
      'network' => {},
      'authentication' => {},
      'kube_proxy' => {},
      'kubelet' => {},
      'telemetry' => {},
      'pod_security_policy' => {},
      'addon_paths' => [],
      'container_runtime' => {}
    }.freeze

    # @param data [Hash]
    # @raise [Pharos::ConfigError]
    # @return [Hash]
    def self.load(data)
      schema = build
      result = schema.call(DEFAULT_DATA.merge(data))
      raise Pharos::ConfigError, result.messages unless result.success?
      result.to_h
    end

    # @return [Dry::Validation::Schema]
    def self.build
      # rubocop:disable Lint/NestedMethodDefinition
      Dry::Validation.Params do
        configure do
          def self.messages
            super.merge(
              en: { errors: { network_dns_replicas: "network.dns_replicas cannot be larger than the number of hosts" } }
            )
          end
        end
        required(:hosts).filled(min_size?: 1) do
          each do
            schema do
              required(:address).filled
              optional(:private_address).filled
              optional(:private_interface).filled
              required(:role).filled(included_in?: ['master', 'worker'])
              optional(:labels).filled
              optional(:taints).each do
                schema do
                  optional(:key).filled(:str?)
                  optional(:value).filled(:str?)
                  required(:effect).filled(included_in?: ['NoSchedule', 'NoExecute'])
                end
              end
              optional(:user).filled
              optional(:ssh_key_path).filled
              optional(:ssh_proxy_command).filled
              optional(:container_runtime).filled(included_in?: ['docker', 'custom_docker', 'cri-o'])
              optional(:environment).filled
              optional(:bastion).schema do
                required(:address).filled(:str?)
                optional(:user).filled(:str?)
                optional(:ssh_key_path).filled(:str?)
              end
            end
          end
        end
        optional(:api).schema do
          optional(:endpoint).filled(:str?)
        end
        optional(:network).schema do
          optional(:provider).filled(included_in?: %(weave calico))
          optional(:dns_replicas).filled(:int?, gt?: 0)
          optional(:service_cidr).filled(:str?)
          optional(:pod_network_cidr).filled(:str?)
          optional(:trusted_subnets).value(:none?)

          optional(:weave).schema do
            optional(:trusted_subnets).each(type?: String)
          end
          optional(:calico).schema do
            optional(:ipip_mode).filled(included_in?: %(Always, CrossSubnet, Never))
          end
        end
        optional(:etcd).schema do
          required(:endpoints).each(type?: String)
          optional(:certificate).filled(:str?)
          optional(:ca_certificate).filled(:str?)
          optional(:key).filled(:str?)
        end
        optional(:authentication).schema do
          optional(:token_webhook).schema do
            required(:config).schema do
              required(:cluster).schema do
                required(:name).filled
                required(:server).filled
                optional(:certificate_authority).filled
              end
              required(:user).schema do
                required(:name).filled
                optional(:client_certificate).filled
                optional(:client_key).filled
              end
            end
            optional(:cache_ttl).filled
          end
        end
        optional(:cloud).schema do
          required(:provider).filled(:str?)
          optional(:config).filled(:str?)
        end
        optional(:audit).schema do
          required(:server).filled(:str?)
        end
        optional(:kube_proxy).schema do
          optional(:mode).filled(included_in?: %w(userspace iptables ipvs))
        end
        optional(:addon_paths).each(type?: String)
        optional(:addons).value(type?: Hash)
        optional(:kubelet).schema do
          optional(:read_only_port).filled(:bool?)
        end
        optional(:telemetry).schema do
          optional(:enabled).filled(:bool?)
        end
        optional(:image_repository).filled(:str?)
        optional(:pod_security_policy).schema do
          optional(:default_policy).filled(:str?)
        end
        optional(:admission_plugins).filled do
          each do
            schema do
              required(:name).filled(:str?)
              optional(:enabled).filled(:bool?)
            end
          end
        end
        optional(:container_runtime).schema do
          optional(:insecure_registries).each(type?: String)
        end

        validate(network_dns_replicas: [:network, :hosts]) do |network, hosts|
          if network && network[:dns_replicas]
            network[:dns_replicas] <= hosts.length
          else
            true
          end
        end
      end
      # rubocop:enable Lint/NestedMethodDefinition
    end
  end
end
