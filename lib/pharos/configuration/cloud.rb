# frozen_string_literal: true

module Pharos
  module Configuration
    class Cloud < Pharos::Configuration::Struct
      attribute :provider, Pharos::Types::String
      attribute :config, Pharos::Types::String
    end
  end
end
