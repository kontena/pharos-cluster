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
      'kubelet' => {}
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
      # rubocop:disable Metrics/BlockLength, Lint/NestedMethodDefinition
      Dry::Validation.Form do
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
              optional(:user).filled
              optional(:ssh_key_path).filled
              optional(:container_runtime).filled(included_in?: ['docker', 'cri-o'])
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
        optional(:addons).value(type?: Hash)
        optional(:kubelet).schema do
          optional(:read_only_port).filled(:bool?)
        end

        validate(network_dns_replicas: [:network, :hosts]) do |network, hosts|
          if network && network[:dns_replicas]
            network[:dns_replicas] <= hosts.length
          else
            true
          end
        end
      end
      # rubocop:enable Metrics/BlockLength, Lint/NestedMethodDefinition
    end
  end
end
