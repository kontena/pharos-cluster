# frozen_string_literal: true

require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/network'
require_relative 'configuration/etcd'
require_relative 'configuration/audit'

module Kupo
  class Config < Dry::Struct
    HOSTS_PER_DNS_REPLICA = 10

    constructor_type :schema

    attribute :hosts, Types::Coercible::Array.of(Kupo::Configuration::Host)
    attribute :network, Kupo::Configuration::Network
    attribute :addons, Kupo::Types::Hash
    attribute :etcd, Kupo::Configuration::Etcd
    attribute :audit, Kupo::Configuration::Audit

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
  end
end
