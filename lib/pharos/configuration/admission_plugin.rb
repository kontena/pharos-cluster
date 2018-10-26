# frozen_string_literal: true

module Pharos
  module Configuration
    class AdmissionPlugin < Pharos::Configuration::Struct
      attribute :name, Pharos::Types::String
      attribute :enabled, Pharos::Types::Bool.default(true)
    end
  end
end
