require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/network'

module Kupo
  class Config < Dry::Struct
    attribute :hosts, Types::Coercible::Array.of(Kupo::Configuration::Host)
    attribute :network, Kupo::Configuration::Network
    attribute :addons, Kupo::Types::Hash
  end
end