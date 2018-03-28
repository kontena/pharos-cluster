# frozen_string_literal: true

require_relative 'token_webhook'

module Kupo
  module Configuration
    class Authentication < Dry::Struct
      constructor_type :schema

      attribute :token_webhook, Kupo::Configuration::TokenWebhook
    end
  end
end
