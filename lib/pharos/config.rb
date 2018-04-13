# frozen_string_literal: true

require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/network'
require_relative 'configuration/etcd'
require_relative 'configuration/authentication'
require_relative 'configuration/cloud'
require_relative 'configuration/audit'

module Pharos
  class Config < Dry::Struct
    HOSTS_PER_DNS_REPLICA = 10

    constructor_type :schema

    attribute :hosts, Types::Coercible::Array.of(Pharos::Configuration::Host)
    attribute :network, Pharos::Configuration::Network
    attribute :cloud, Pharos::Configuration::Cloud
    attribute :addons, Pharos::Types::Hash
    attribute :etcd, Pharos::Configuration::Etcd
    attribute :authentication, Pharos::Configuration::Authentication
    attribute :audit, Pharos::Configuration::Audit

    # written by Pharos::Phases::CreateBootstrapToken, read by Pharos::Phases::JoinNode
    attr_accessor :join_command

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
      hosts.select { |h| h.role == 'etcd' }
    end

    def etcd_leader
      etcd_hosts[0]
    end
  end
end
