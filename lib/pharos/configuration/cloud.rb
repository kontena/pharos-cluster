# frozen_string_literal: true

module Pharos
  module Configuration
    class Cloud < Dry::Struct
      constructor_type :schema

      attribute :provider, Pharos::Types::String
      attribute :config, Pharos::Types::String
    end
  end
end
