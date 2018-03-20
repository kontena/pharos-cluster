module Kupo
  module Addons
    class LocalVolumeProvisioner < Kupo::Addon

      name 'local-volume-provisioner'
      version '2.0.0'
      license 'Apache License 2.0'

      struct {
        attribute :node_selector, Kupo::Types::Hash
      }

      schema {
        optional(:node_selector).filled(:hash?)
      }

    end
  end
end