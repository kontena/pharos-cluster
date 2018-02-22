require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/features'

module Kontadm
  class Config < Dry::Struct
    attribute :hosts, Types::Coercible::Array.of(Kontadm::Configuration::Host)
    attribute :features, Kontadm::Configuration::Features
  end
end