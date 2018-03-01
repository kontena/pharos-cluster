module Shokunin
  module Addons
    class HostUpgrades < Shokunin::Addon

      name 'host-upgrades'
      version '0.1.0'
      license 'Apache License 2.0'

      struct { |s|
        s.attribute :interval, Shokunin::Types::String
      }
      schema {
        required(:interval).filled(:str?, :duration?)
      }

      def install
        apply_stack({
          interval: duration.parse(config.interval).to_sec
        })
      end
    end
  end
end