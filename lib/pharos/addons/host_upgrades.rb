# frozen_string_literal: true

module Pharos
  module Addons
    class HostUpgrades < Pharos::Addon
      name 'host-upgrades'
      version '0.1.0'
      license 'Apache License 2.0'

      struct {
        attribute :interval, Pharos::Types::String
      }

      schema {
        required(:interval).filled(:str?, :duration?)
      }

      def install
        apply_stack(
          interval: duration.parse(config.interval).to_sec
        )
      end
    end
  end
end
