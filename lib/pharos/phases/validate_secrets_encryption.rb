# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateSecretsEncryption < Pharos::Phase
      title "Validate secrets encryption"

      PHAROS_DIR = '/etc/pharos'
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze

      def call
        mutex.synchronize do
          return if cluster_context['secrets_encryption']

          if existing_keys_valid?
            cluster_context['secrets_encryption'] = existing_content
          end
        end
      end

      # @return [String,NilClass]
      def existing_content
        return @existing_content if @existing_content

        file = ssh.file(SECRETS_CFG_FILE)
        return nil unless file.exist?

        @existing_content = file.read
      end

      # @return [TrueClass,FalseClass]
      def existing_keys_valid?
        logger.debug { "Checking if secrets encryption is already configured ..." }

        content = existing_content
        return false unless content

        logger.debug { "Validating existing encryption keys ..." }
        config = Pharos::YamlFile.new(StringIO.new(content)).load

        config['resources'].each do |resource|
          resource['providers'].each do |provider|
            next unless provider['aescbc']

            if !provider['aescbc'].fetch('keys', []).empty?
              logger.debug { "Reusing existing encryption keys ..." }
              return true
            end
          end
        end
        false
      end
    end
  end
end
