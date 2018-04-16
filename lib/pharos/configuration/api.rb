
# frozen_string_literal: true

module Pharos
  module Configuration
    class Api < Dry::Struct
      constructor_type :schema

      attribute :endpoint, Pharos::Types::String
    end
  end
end
