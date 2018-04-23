# frozen_string_literal: true

require "base64"

module Pharos
  module Phases
    class ConfigureSecretsEncryption < Pharos::Phase
      title "Configure secrets encryption"

      PHAROS_DIR = '/etc/pharos'
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze

      def call
        keys = cluster_context['secrets_encryption'] || read_config_keys || generate_keys

        ensure_config(keys)

        cluster_context['secrets_encryption'] = keys
      end

      # @return [Hash, nil]
      def read_config_keys
        logger.debug { "Checking if secrets encryption is already configured ..." }
        file = @ssh.file(SECRETS_CFG_FILE)
        return nil unless file.exist?

        logger.debug { "Reusing existing encryption keys ..." }
        config = Pharos::YamlFile.new(file).load

        keys = {}
        config['resources'].each do |resource|
          resource['providers'].each do |provider|
            next unless provider['aescbc']

            provider['aescbc']['keys'].each do |key|
              keys[key['name']] = key['secret']
            end
          end
        end
        keys
      end

      # @return [Hash]
      def generate_keys
        logger.info { "Generating new encryption keys ..." }

        {
          'key1' => Base64.strict_encode64(SecureRandom.random_bytes(32))
        }
      end

      def ensure_config(keys)
        cfg_file = @ssh.file(SECRETS_CFG_FILE)
        return if cfg_file.exist?

        logger.info { "Creating secrets encryption configuration ..." }
        @ssh.exec!("test -d #{SECRETS_CFG_DIR} || sudo install -m 0700 -d #{SECRETS_CFG_DIR}")
        cfg_file.write(parse_resource_file('secrets/encryption-config.yml.erb', keys))
        cfg_file.chmod('0700')
      end
    end
  end
end
