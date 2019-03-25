# frozen_string_literal: true

module Pharos
  module Configuration
    class Kubelet < Pharos::Configuration::Struct
      attribute :read_only_port, Pharos::Types::Bool.default(false)
      attribute :feature_gates, Pharos::Types::Strict::Hash
    end
  end
end
