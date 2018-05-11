# frozen_string_literal: true

module Pharos
  module Configuration
    class Kubelet < Dry::Struct
      constructor_type :schema

      attribute :read_only_port, Pharos::Types::Bool.default(false)
    end
  end
end
