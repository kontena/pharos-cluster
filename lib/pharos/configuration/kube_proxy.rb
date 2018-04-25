# frozen_string_literal: true

module Pharos
  module Configuration
    class KubeProxy < Dry::Struct
      constructor_type :schema

      attribute :mode, Pharos::Types::String
    end
  end
end
