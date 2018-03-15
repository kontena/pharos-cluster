# frozen_string_literal: true

module Kupo
  module Addons
    class HostUpgrades < Kupo::Addon
      name 'host-upgrades'
      version '0.1.0'
      license 'Apache License 2.0'

      struct do
        attribute :interval, Kupo::Types::String
      end

      schema do
        required(:interval).filled(:str?, :duration?)
      end

      def install
        apply_stack(
          interval: duration.parse(config.interval).to_sec
        )
      end
    end
  end
end
