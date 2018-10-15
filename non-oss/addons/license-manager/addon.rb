# frozen_string_literal: true

module Pharos
  module Addons
    class LicenseManager < Pharos::Addon
      version Pharos::VERSION
      license 'Kontena License'
      enable!

      config {
        attribute :key, Pharos::Types::String.default('EVALUATION')
      }

      config_schema {
        optional(:key).filled(:str?)
      }
    end
  end
end
