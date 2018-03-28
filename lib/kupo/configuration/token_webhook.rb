# frozen_string_literal: true

module Kupo
  module Configuration
    class TokenWebhook < Dry::Struct
      constructor_type :schema

      attribute :config, Kupo::Types::Hash
      attribute :cache_ttl, Kupo::Types::String
    end
  end
end
