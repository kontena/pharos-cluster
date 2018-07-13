# frozen_string_literal: true

module Pharos
  module Configuration
    class KubeProxy < Pharos::Configuration::Struct
      attribute :mode, Pharos::Types::String.default('iptables')
    end
  end
end
