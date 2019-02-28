# frozen_string_literal: true

module Pharos
  module Configuration
    class OIDC < Pharos::Configuration::Struct
      attribute :issuer_url, Pharos::Types::String
      attribute :client_id, Pharos::Types::String
      attribute :username_claim, Pharos::Types::String
      attribute :username_prefix, Pharos::Types::String
      attribute :groups_prefix, Pharos::Types::String
      attribute :groups_claim, Pharos::Types::String
      attribute :ca_file, Pharos::Types::String
    end
  end
end
