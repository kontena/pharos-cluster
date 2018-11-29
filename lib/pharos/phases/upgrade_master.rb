# frozen_string_literal: true

module Pharos
  module Phases
    class UpgradeMaster < Pharos::Phase
      title "Upgrade master"

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def upgrade?
        current = current_apiserver_version
        return false if current.nil?

        current_major_minor = parse_major_minor(current)
        logger.debug { "Current Kubernetes API server version: #{current} (#{current_major_minor})" }

        new_major_minor = parse_major_minor(Pharos::KUBE_VERSION)

        current_major_minor != new_major_minor
      end

      def current_apiserver_version
        file = ssh.file('/etc/kubernetes/manifests/kube-apiserver.yaml')
        return nil unless file.exist?

        manifest = Pharos::YamlFile.new(file).load
        image = manifest.dig('spec', 'containers')&.find { |c| c['name'] == 'kube-apiserver' }&.dig('image')
        image&.split(':')&.last&.delete_prefix('v')
      end

      # @param version [String]
      # @return [String]
      def parse_major_minor(version)
        version.split('.').first(2).join('.')
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
