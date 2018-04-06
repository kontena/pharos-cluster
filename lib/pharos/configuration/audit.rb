
# frozen_string_literal: true

module Pharos
  module Configuration
    class Audit < Dry::Struct
      constructor_type :schema

      attribute :server, Pharos::Types::String
    end
  end
end
