# frozen_string_literal: true

require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/api'
require_relative 'configuration/network'
require_relative 'configuration/etcd'
require_relative 'configuration/authentication'
require_relative 'configuration/cloud'
require_relative 'configuration/audit'
require_relative 'configuration/file_audit'
require_relative 'configuration/webhook_audit'
require_relative 'configuration/kube_proxy'
require_relative 'configuration/kubelet'
require_relative 'configuration/control_plane'
require_relative 'configuration/pod_security_policy'
require_relative 'configuration/telemetry'
require_relative 'configuration/admission_plugin'
require_relative 'configuration/container_runtime'

module Pharos
  class Config < Pharos::Configuration::Struct
    HOSTS_PER_DNS_REPLICA = 10

    using Pharos::CoreExt::DeepTransformKeys

    # @param raw_data [Hash]
    # @raise [Pharos::ConfigError]
    # @return [Pharos::Config]
    def self.load(raw_data)
      schema_data = Pharos::ConfigSchema.load(raw_data)

      config = new(schema_data)
      config.data = raw_data.freeze

      # inject api_endpoint & config reference to each host object
      config.hosts.each do |host|
        host.api_endpoint = config.api&.endpoint
        host.config = config
      end

      # de-duplicate bastions (if two hosts share an identical bastion, make it the same object to avoid multiple gateways)
      config.hosts.reject { |h| h.bastion.nil? }.permutation(2) do |host_a, host_b|
        if host_a.bastion == host_b.bastion && host_a.bastion.object_id != host_b.bastion.object_id
          host_b.attributes[:bastion] = host_a.bastion
        end
      end

      # link real hosts to bastion's @host to avoid multiple gateways
      config.bastions.each do |bastion|
        existing_host = config.hosts.find { |host| bastion == host }
        bastion.host = existing_host if existing_host
      end

      config.hosts.each do |host|
        if chain = loop?(host)
          raise Pharos::ConfigError, "hosts" => ["infinite bastion loop for host #{host.address} (#{chain.join(' => ')})"]
        end
      end

      config
    end

    # @return [Array<String>,false] an array of host addresses if there is an infinite loop, false when there's no loop
    def self.loop?(host, chain = [])
      return false if host.bastion.nil?

      chain << host.address
      return chain if chain.count(host.address) > 1

      loop?(host.bastion.host, chain)
    end
    private_class_method :loop?

    attribute :hosts, Types::Coercible::Array.of(Pharos::Configuration::Host)
    attribute :network, Pharos::Configuration::Network
    attribute :kube_proxy, Pharos::Configuration::KubeProxy
    attribute :api, Pharos::Configuration::Api
    attribute :etcd, Pharos::Configuration::Etcd
    attribute :cloud, Pharos::Configuration::Cloud
    attribute :authentication, Pharos::Configuration::Authentication
    attribute :audit, Pharos::Configuration::Audit
    attribute :kubelet, Pharos::Configuration::Kubelet
    attribute :control_plane, Pharos::Configuration::ControlPlane
    attribute :telemetry, Pharos::Configuration::Telemetry
    attribute :pod_security_policy, Pharos::Configuration::PodSecurityPolicy
    attribute :image_repository, Pharos::Types::String.default('registry.pharos.sh/kontenapharos')
    attribute :addon_paths, Pharos::Types::Array.default(proc { [] })
    attribute :addons, Pharos::Types::Hash.default(proc { {} })
    attribute :admission_plugins, Types::Coercible::Array.of(Pharos::Configuration::AdmissionPlugin)
    attribute :container_runtime, Pharos::Configuration::ContainerRuntime
    attribute :name, Pharos::Types::String

    attr_accessor :data

    # @return [Array<Pharos::Configuration::Bastion>]
    def bastions
      hosts.map(&:bastion).compact
    end

    # @return [Integer]
    def dns_replicas
      return network.dns_replicas if network.dns_replicas
      return 1 if hosts.length == 1

      1 + (hosts.length / HOSTS_PER_DNS_REPLICA.to_f).ceil
    end

    # @return [Array<Pharos::Configuration::Node>]
    def master_hosts
      hosts.select { |h| h.role == 'master' }.sort_by(&:master_sort_score)
    end

    # @return [Pharos::Configuration::Node]
    def master_host
      master_hosts.first
    end

    # @return [Array<Pharos::Configuration::Node>]
    def worker_hosts
      @worker_hosts ||= hosts.select { |h| h.role == 'worker' }
    end

    # @return [Array<Pharos::Configuration::Node>]
    def etcd_hosts
      return [] if etcd&.endpoints

      etcd_hosts = hosts.select { |h| h.role == 'etcd' }
      if etcd_hosts.empty?
        master_hosts.sort_by(&:etcd_sort_score)
      else
        etcd_hosts.sort_by(&:etcd_sort_score)
      end
    end

    # @param peer [Pharos::Configuration::Host]
    # @return [String]
    def etcd_peer_address(peer)
      etcd_regions.size > 1 ? peer.address : peer.peer_address
    end

    # @return [Array<String>]
    def etcd_regions
      @etcd_regions ||= etcd_hosts.map(&:region).compact.uniq
    end

    # @return [Array<String>]
    def regions
      @regions ||= hosts.map(&:region).compact.uniq
    end

    # @raise [Pharos::Error] when no master can create a kube client instance
    # @return [K8s::Client]
    def kube_client
      # Return a kube_client instance from a master host that already has one initialized
      # or return a kube_client instance from a master host that succeeds in creating one
      (master_hosts.find(&:kube_client?) || master_hosts.find(&:kube_client))&.kube_client || raise(Pharos::Error, 'no kube_client available')
    end

    # @return [nil]
    def disconnect
      hosts.group_by(&:gateway?).tap do |has_gateway|
        has_gateway[false]&.each(&:disconnect) # disconnect non-gw hosts first
        has_gateway[true]&.each(&:disconnect)
      end

      # disconnect non-listed bastion hosts
      bastions.map(&:host).reject { |bastion_host| hosts.include?(bastion_host) }.map(&:disconnect)

      nil
    end

    # @param key [Symbol]
    # @param value [Pharos::Configuration::Struct]
    # @raise [Pharos::ConfigError]
    def set(key, value)
      raise Pharos::Error, "Cannot override #{key}." if data[key.to_s]

      attributes[key] = value
    end

    # @return [String]
    def to_yaml
      YAML.dump(to_h.deep_stringify_keys)
    end

    # @example dig network provider
    #   config.dig("network", "provider")
    # @param keys [String,Symbol]
    # @return [Object,nil] returns nil when any part of the chain is unreachable
    def dig(*keys)
      keys.inject(self) do |memo, item|
        if memo.is_a?(Array) && item.is_a?(Integer)
          memo.send(:[], item)
        elsif memo.respond_to?(item.to_sym)
          memo.send(item.to_sym)
        end
      end
    end
  end
end
