# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateWorker < Pharos::Phase
      def call
        migrate_0_5_to_0_6 if migrate_0_5_to_0_6?
      end

      def migrate_0_5_to_0_6?
        !@ssh.file('/etc/kubernetes/kubelet.conf').read.include?('localhost:6443')
      end

      def migrate_0_5_to_0_6
        Out.info { 'Migrating from 0.5 to 0.6 ...' }
        exec_script(
          'migrations/migrate_worker_05_to_06.sh',
          PEER_IP: @master.peer_address
        )
      end
    end
  end
end
