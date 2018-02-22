require_relative "feature/host_update"
require_relative "feature/network"

module Kontadm::Configuration
  class Features < Dry::Struct
    constructor_type :schema

    attribute :host_updates, Kontadm::Configuration::Feature::HostUpdate
    attribute :network, Kontadm::Configuration::Feature::Network
  end
end