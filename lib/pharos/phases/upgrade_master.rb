# frozen_string_literal: true

require_relative 'mixins/psp'

module Pharos
  module Phases
    class UpgradeMaster < Pharos::Phase
      include Pharos::Phases::Mixins::PSP
      title "Upgrade master"

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def upgrade?
        file = transport.file('/etc/kubernetes/manifests/kube-apiserver.yaml')
        return false unless file.exist?

        match = file.read.match(/kube-apiserver.*:v(.+)/)
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

      # @return [Boolean]
      def pod_security_disabled?
        api_manifest = transport.file('/etc/kubernetes/manifests/kube-apiserver.yaml')
        return false unless api_manifest.exist?

        !api_manifest.read.match?(/--enable-admission-plugins=.*PodSecurityPolicy/)
      end

      def call
        if upgrade?
          upgrade_kubeadm
          apply_psp_stack if pod_security_disabled?
          upgrade
        else
          logger.info { "Kubernetes control plane is up-to-date." }
        end
      end

      def upgrade_kubeadm
        host_configurer.upgrade_kubeadm(Pharos::KUBEADM_VERSION)
      end

      def upgrade
        cfg = kubeadm.generate_yaml_config

        logger.info { "Upgrading control plane to v#{Pharos::KUBE_VERSION} ..." }
        logger.debug { cfg }

        transport.tempfile(content: cfg, prefix: "kubeadm.cfg") do |tmp_file|
          transport.exec!("sudo /usr/local/bin/pharos-kubeadm-#{Pharos::KUBEADM_VERSION} upgrade apply #{Pharos::KUBE_VERSION} -y --ignore-preflight-errors=all --allow-experimental-upgrades --config #{tmp_file}")
        end

        logger.info { "Control plane upgrade succeeded!" }
        cluster_context['api_upgraded'] = true
      end
    end
  end
end
