# frozen_string_literal: true

module Pharos
  module Configuration
    class WebhookAudit < Pharos::Configuration::Struct
      attribute :server, Pharos::Types::String
    end
  end
end
