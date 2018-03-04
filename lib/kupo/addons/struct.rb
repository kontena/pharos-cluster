require 'dry-struct'

module Kupo
  module Addons
    class Struct < Dry::Struct
      constructor_type :schema

      attribute :enabled, Kupo::Types::Strict::Bool
    end
  end
end