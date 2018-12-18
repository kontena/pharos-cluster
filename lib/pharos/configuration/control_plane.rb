# frozen_string_literal: true

module Pharos
  module Configuration
    class ControlPlane < Pharos::Configuration::Struct
      attribute :use_proxy, Pharos::Types::Bool.default(false)
    end
  end
end
