# frozen_string_literal: true

module Pharos
  module Configuration
    class Telemetry < Pharos::Configuration::Struct
      attribute :enabled, Pharos::Types::Bool.default(true)
    end
  end
end
