# frozen_string_literal: true

require 'dry-struct'

module Pharos
  module Addons
    class Struct < Pharos::Configuration::Struct
      attribute :enabled, Pharos::Types::Strict::Bool
    end
  end
end
