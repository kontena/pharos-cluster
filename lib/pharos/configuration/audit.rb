# frozen_string_literal: true

module Pharos
  module Configuration
    class Audit < Pharos::Configuration::Struct
      attribute :server, Pharos::Types::String
    end
  end
end
