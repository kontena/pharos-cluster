require_relative "feature/host_update"
require_relative "feature/network"

module Shokunin::Configuration
  class Features < Dry::Struct
    constructor_type :schema

    attribute :host_updates, Shokunin::Configuration::Feature::HostUpdate
    attribute :network, Shokunin::Configuration::Feature::Network
  end
end