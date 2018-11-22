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

        match = file.read.match(/kube-apiserver-.+:v(.+)/)
        current_major_minor = parse_major_minor(match[1])
        new_major_minor = parse_major_minor(Pharos::KUBE_VERSION)
        return false if current_major_minor == new_major_minor

        true
      end

      # @param version [String]
      # @return [String]
      def parse_major_minor(version)
        version.split('.')[0...2].join('.')
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

        logger.info { "Upgrading control plane to v#{Pharos::KUBE_VERSION} ..." }
        logger.debug { cfg.to_yaml }

        ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          ssh.exec!("sudo /usr/local/bin/pharos-kubeadm-#{Pharos::KUBEADM_VERSION} upgrade apply #{Pharos::KUBE_VERSION} -y --ignore-preflight-errors=all --allow-experimental-upgrades --config #{tmp_file}")
        end

        logger.info { "Control plane upgrade succeeded!" }
        cluster_context['api_upgraded'] = true
      end
    end
  end
end
