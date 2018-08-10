# frozen_string_literal: true

require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/api'
require_relative 'configuration/network'
require_relative 'configuration/etcd'
require_relative 'configuration/authentication'
require_relative 'configuration/cloud'
require_relative 'configuration/audit'
require_relative 'configuration/kube_proxy'
require_relative 'configuration/kubelet'

module Pharos
  class Config < Pharos::Configuration::Struct
    HOSTS_PER_DNS_REPLICA = 10

    # @param raw_data [Hash]
    # @raise [Pharos::ConfigError]
    # @return [Pharos::Config]
    def self.load(raw_data)
      schema_data = Pharos::ConfigSchema.load(raw_data)

      config = new(schema_data)
      config.data = raw_data.freeze

      # inject api_endpoint to each host object
      config.hosts.each { |h| h.api_endpoint = config.api&.endpoint }

      config
    end

    attribute :hosts, Types::Coercible::Array.of(Pharos::Configuration::Host)
    attribute :network, Pharos::Configuration::Network
    attribute :kube_proxy, Pharos::Configuration::KubeProxy
    attribute :api, Pharos::Configuration::Api
    attribute :etcd, Pharos::Configuration::Etcd
    attribute :cloud, Pharos::Configuration::Cloud
    attribute :authentication, Pharos::Configuration::Authentication
    attribute :audit, Pharos::Configuration::Audit
    attribute :kubelet, Pharos::Configuration::Kubelet
    attribute :image_repository, Pharos::Types::String.default('quay.io/kontena')
    attribute :addon_paths, Pharos::Types::Array.default([])
    attribute :addons, Pharos::Types::Hash.default({})

    attr_accessor :data

    # @return [Integer]
    def dns_replicas
      return network.dns_replicas if network.dns_replicas
      return 1 if hosts.length == 1
      1 + (hosts.length / HOSTS_PER_DNS_REPLICA.to_f).ceil
    end

    # @return [Array<Pharos::Configuration::Node>]
    def master_hosts
      @master_hosts ||= hosts.select { |h| h.role == 'master' }
    end

    # @return [Pharos::Configuration::Node]
    def master_host
      @master_host ||= master_hosts.first
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
        master_hosts
      else
        etcd_hosts
      end
    end

    # @return [String]
    def to_yaml
      JSON.parse(to_h.to_json).to_yaml
    end
  end
end
