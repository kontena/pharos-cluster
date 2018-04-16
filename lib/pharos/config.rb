# frozen_string_literal: true

require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/api'
require_relative 'configuration/network'
require_relative 'configuration/etcd'
require_relative 'configuration/authentication'
require_relative 'configuration/cloud'
require_relative 'configuration/audit'
require_relative 'configuration/kube_proxy'

module Pharos
  class Config < Dry::Struct
    HOSTS_PER_DNS_REPLICA = 10

    constructor_type :schema

    attribute :hosts, Types::Coercible::Array.of(Pharos::Configuration::Host)
    attribute :api, Pharos::Configuration::Api
    attribute :network, Pharos::Configuration::Network
    attribute :cloud, Pharos::Configuration::Cloud
    attribute :addons, Pharos::Types::Hash
    attribute :etcd, Pharos::Configuration::Etcd
    attribute :authentication, Pharos::Configuration::Authentication
    attribute :audit, Pharos::Configuration::Audit
    attribute :kube_proxy, Pharos::Configuration::KubeProxy

    # @return [Integer]
    def dns_replicas
      if network.dns_replicas
        network.dns_replicas
      elsif hosts.length == 1
        1
      else
        1 + (hosts.length / HOSTS_PER_DNS_REPLICA.to_f).ceil
      end
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
      etcd_hosts = hosts.select { |h| h.role == 'etcd' }
      if etcd_hosts.empty?
        master_hosts
      else
        etcd_hosts
      end
    end

    # @return [Pharos::Configuration::Host]
    def etcd_host
      etcd_hosts[0]
    end
  end
end
