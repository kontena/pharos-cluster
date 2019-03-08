# frozen_string_literal: true

module Pharos
  module Configuration
    class Api < Pharos::Configuration::Struct
      attribute :endpoint, Pharos::Types::String
      attribute :feature_gates, Pharos::Types::Strict::Hash
    end
  end
end
