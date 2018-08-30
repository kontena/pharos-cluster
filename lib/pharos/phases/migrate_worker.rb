# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateWorker < Pharos::Phase
      title "Migrate worker"

      def call
        if migrate_1_1_to_1_2?
          migrate_1_1_to_1_2
        elsif migrate_1_3?
          migrate_1_3
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

      def migrate_1_3?
        return false unless @ssh.file('/etc/kubernetes/kubelet.conf').exist?
        return false if @ssh.file('/var/lib/kubelet/config.yaml').exist?

        true
      end

      def migrate_1_3
        logger.info { 'Upgrade kubelet config' }

        # use the new version of kubeadm to write out /var/lib/kubelet/config.yaml for new kubelet version to be installed
        # the kube master must be running, which is the case for upgrades
        host_configurer.upgrade_kubeadm(Pharos::KUBEADM_VERSION)

        @ssh.exec!("sudo /usr/local/bin/pharos-kubeadm-#{Pharos::KUBEADM_VERSION} upgrade node config --kubelet-version=v#{Pharos::KUBE_VERSION}")
        kubeadm_flags = @ssh.file("/var/lib/kubelet/kubeadm-flags.env")
        unless kubeadm_flags.exist?
          kubeadm_flags.write('KUBELET_KUBEADM_ARGS=--cni-bin-dir=/opt/cni/bin --cni-conf-dir=/etc/cni/net.d --network-plugin=cni')
        end
      end
    end
  end
end
