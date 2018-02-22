module Kontadm::Configuration::Feature
  class HostUpdate < Dry::Struct
    constructor_type :schema

    attribute :interval, Kontadm::Types::Strict::String
    attribute :reboot, Kontadm::Types::Strict::Bool.default(false)
  end
end