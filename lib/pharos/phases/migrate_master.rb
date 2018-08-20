# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      title "Migrate master"

      def call
        if migrate_1_1_to_1_2?
          migrate_1_1_to_1_2
        else
          logger.info { 'Nothing to migrate.' }
        end
      end

      def migrate_1_1_to_1_2?
        @ssh.file('/etc/systemd/system/kubelet.service.d/5-pharos.conf').exist?
      end

      def migrate_1_1_to_1_2
        logger.info { 'Migrating from 1.1 to 1.2 ...' }
        @ssh.file('/etc/systemd/system/kubelet.service.d/5-pharos.conf').unlink
      end
    end
  end
end
