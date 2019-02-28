# frozen_string_literal: true

require_relative "file_audit"
require_relative "webhook_audit"

module Pharos
  module Configuration
    class Audit < Pharos::Configuration::Struct
      attribute :webhook, Pharos::Configuration::WebhookAudit
      attribute :file, Pharos::Configuration::FileAudit
    end
  end
end
