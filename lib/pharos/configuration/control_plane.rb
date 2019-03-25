# frozen_string_literal: true

module Pharos
  module Configuration
    class ControlPlane < Pharos::Configuration::Struct
      attribute :use_proxy, Pharos::Types::Bool.default(false)
      attribute :feature_gates, Pharos::Types::Strict::Hash
    end
  end
end
