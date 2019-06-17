# frozen_string_literal: true

module Pharos
  module Configuration
    class Repository < Pharos::Configuration::Struct
      attribute :name, Pharos::Types::String
      attribute :contents, Pharos::Types::String
      attribute :key_url, Pharos::Types::String
    end
  end
end
