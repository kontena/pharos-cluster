require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/network'

module Shokunin
  class Config < Dry::Struct
    attribute :hosts, Types::Coercible::Array.of(Shokunin::Configuration::Host)
    attribute :network, Shokunin::Configuration::Network
    attribute :addons, Shokunin::Types::Hash
  end
end