# frozen_string_literal: true

module Pharos
  module Phases
    class UpgradeMaster < Pharos::Phase
      title "Upgrade master"

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def upgrade?
        file = ssh.file('/etc/kubernetes/manifests/kube-apiserver.yaml')
        return false unless file.exist?
        return false if file.read.match?(/kube-apiserver-.+:v#{Pharos::KUBE_VERSION}/)

        true
      end

      def call
        if upgrade?
          upgrade_kubeadm
          upgrade
        else
          logger.info { "Kubernetes control plane is up-to-date." }
        end
      end

      def upgrade_kubeadm
        host_configurer.upgrade_kubeadm(Pharos::KUBEADM_VERSION)
      end

      def upgrade
        cfg = kubeadm.generate_config

        logger.info { "Upgrading control plane ..." }
        logger.debug { cfg.to_yaml }

        ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          ssh.exec!("sudo /usr/local/bin/pharos-kubeadm-#{Pharos::KUBEADM_VERSION} upgrade apply #{Pharos::KUBE_VERSION} -y --ignore-preflight-errors=all --allow-experimental-upgrades --config #{tmp_file}")
        end

        logger.info { "Control plane upgrade succeeded!" }
      end
    end
  end
end
