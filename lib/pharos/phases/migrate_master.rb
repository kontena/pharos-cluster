# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      title "Migrate master"

      def call
        migrate_0_5_to_0_6 if migrate_0_5_to_0_6?
      end

      def migrate_0_5_to_0_6?
        @ssh.file('/etc/kubernetes/manifests/etcd.yaml').exist?
      end

      def migrate_0_5_to_0_6
        logger.info { 'Migrating from 0.5 to 0.6 ...' }
        exec_script(
          'migrations/migrate_master_05_to_06.sh',
          PEER_IP: @host.peer_address
        )
      end
    end
  end
end
