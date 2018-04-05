# frozen_string_literal: true

require_relative 'token_webhook'

module Pharos
  module Configuration
    class Authentication < Dry::Struct
      constructor_type :schema

      attribute :token_webhook, Pharos::Configuration::TokenWebhook
    end
  end
end
