require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/features'

module Shokunin
  class Config < Dry::Struct
    attribute :hosts, Types::Coercible::Array.of(Shokunin::Configuration::Host)
    attribute :features, Shokunin::Configuration::Features
  end
end