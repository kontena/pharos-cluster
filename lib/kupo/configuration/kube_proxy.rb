# frozen_string_literal: true

module Kupo
  module Configuration
    class KubeProxy < Dry::Struct
      constructor_type :schema

      attribute :mode, Kupo::Types::String
    end
  end
end
