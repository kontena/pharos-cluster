# frozen_string_literal: true

require 'dry-struct'

module Pharos
  module Addons
    class Struct < Dry::Struct
      constructor_type :schema

      attribute :enabled, Pharos::Types::Strict::Bool
    end
  end
end
