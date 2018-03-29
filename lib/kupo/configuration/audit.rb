# frozen_string_literal: true

module Kupo
  module Configuration
    class Audit < Dry::Struct
      constructor_type :schema

      attribute :server, Kupo::Types::String
    end
  end
end
