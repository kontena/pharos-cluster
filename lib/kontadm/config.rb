require 'dry-struct'
require_relative 'types'
require_relative 'configuration/host'
require_relative 'configuration/feature'

module Kontadm
  class Config < Dry::Struct
    attribute :hosts, Types::Coercible::Array.of(Kontadm::Configuration::Host)
    attribute :features, Types::Coercible::Array.of(Kontadm::Configuration::Feature).optional
  end
end