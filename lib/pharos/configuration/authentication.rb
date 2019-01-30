# frozen_string_literal: true

require_relative 'token_webhook'
require_relative 'oidc'

module Pharos
  module Configuration
    class Authentication < Pharos::Configuration::Struct
      attribute :token_webhook, Pharos::Configuration::TokenWebhook
      attribute :oidc, Pharos::Configuration::OIDC
    end
  end
end
