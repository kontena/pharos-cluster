# frozen_string_literal: true

require 'dry-struct'

module Kupo::Phases
  class Component < Dry::Struct
    constructor_type :schema

    attribute :name, Kupo::Types::String
    attribute :version, Kupo::Types::String
    attribute :license, Kupo::Types::String
  end
end
