require 'dry-struct'

module Shokunin::Phases
  class Component < Dry::Struct
    constructor_type :schema

    attribute :name, Shokunin::Types::String
    attribute :version, Shokunin::Types::String
    attribute :license, Shokunin::Types::String
  end
end