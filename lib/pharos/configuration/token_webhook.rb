# frozen_string_literal: true

module Pharos
  module Configuration
    class TokenWebhook < Pharos::Configuration::Struct
      attribute :config, Pharos::Types::Hash
      attribute :cache_ttl, Pharos::Types::String
    end
  end
end
