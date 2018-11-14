# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureSecretsEncryption < Pharos::Phase
      title "Configure secrets encryption"

      PHAROS_DIR = '/etc/pharos'
      SECRETS_CFG_DIR = (PHAROS_DIR + '/secrets-encryption').freeze
      SECRETS_CFG_FILE = (SECRETS_CFG_DIR + '/config.yml').freeze

      def call
        logger.info { "Writing secrets encryption configuration ..." }
        ssh.exec!("test -d #{SECRETS_CFG_DIR} || sudo install -m 0700 -d #{SECRETS_CFG_DIR}")
        cfg_file = ssh.file(SECRETS_CFG_FILE)
        cfg_file.write(cluster_context['secrets_encryption'])
        cfg_file.chmod('0700')
      end
    end
  end
end
