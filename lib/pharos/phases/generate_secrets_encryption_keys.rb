# frozen_string_literal: true

require "base64"

module Pharos
  module Phases
    class GenerateSecretsEncryptionKeys < Pharos::Phase
      title "Generate secrets encryption keys"

      def call
        cluster_context['secrets_encryption'] = generate_keys
      end

      # @return [Hash]
      def generate_keys
        logger.info { "Generating new encryption keys ..." }

        parse_resource_file(
          'secrets/encryption-config.yml.erb',
          'key1' => Base64.strict_encode64(SecureRandom.random_bytes(32))
        )
      end
    end
  end
end
