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
require_relative 'configuration/kubelet'

module Pharos
  class Config < Dry::Struct
    HOSTS_PER_DNS_REPLICA = 10

    constructor_type :schema

    attribute :hosts, Types::Coercible::Array.of(Pharos::Configuration::Host)
    attribute :network, Pharos::Configuration::Network
    attribute :kube_proxy, Pharos::Configuration::KubeProxy
    attribute :api, Pharos::Configuration::Api
    attribute :etcd, Pharos::Configuration::Etcd
    attribute :cloud, Pharos::Configuration::Cloud
    attribute :authentication, Pharos::Configuration::Authentication
    attribute :audit, Pharos::Configuration::Audit
    attribute :kubelet, Pharos::Configuration::Kubelet
    attribute :addons, Pharos::Types::Hash.default({})

    attr_accessor :data

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

    # @return [Array<Pharos::Configuration::Node>]
    def sorted_master_hosts
      @sorted_master_hosts ||= master_hosts.sort_by(&:master_sort_score)
    end

    # @return [Pharos::Configuration::Node]
    def master_host
      @master_host ||= sorted_master_hosts.first
    end

    # @return [Array<Pharos::Configuration::Node>]
    def worker_hosts
      @worker_hosts ||= hosts.select { |h| h.role == 'worker' }
    end

    # @return [Boolean]
    def etcd_hosts?
      !etcd&.endpoints
    end

    # @return [Array<Pharos::Configuration::Node>]
    def etcd_hosts
      @etcd_hosts ||= if !etcd_hosts?
                        []
                      elsif hosts.any? { |h| h.role == 'etcd' }
                        hosts.select { |h| h.role == 'etcd' }.sort_by(&:etcd_sort_score)
                      else
                        hosts.select { |h| h.role == 'master' }.sort_by(&:etcd_sort_score)
                      end
    end

    # @return [String]
    def api_endpoint
      api&.endpoint || master_host.address
    end

    def to_yaml
      JSON.parse(to_h.to_json).to_yaml
    end
  end
end
