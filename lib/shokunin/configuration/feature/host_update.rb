module Shokunin::Configuration::Feature
  class HostUpdate < Dry::Struct
    constructor_type :schema

    attribute :interval, Shokunin::Types::Strict::String
    attribute :reboot, Shokunin::Types::Strict::Bool.default(false)
  end
end