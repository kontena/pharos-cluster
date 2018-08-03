# frozen_string_literal: true

module Pharos
  module Configuration
    class Kubelet < Pharos::Configuration::Struct
      attribute :read_only_port, Pharos::Types::Bool.default(false)
    end
  end
end
