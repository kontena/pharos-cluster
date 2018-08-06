# frozen_string_literal: true

module Pharos
  module Phases
    class UpgradeMaster < Pharos::Phase
      title "Upgrade master"

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def upgrade?
        file = @ssh.file('/etc/kubernetes/manifests/kube-apiserver.yaml')
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

        dns_patch_thread = create_dns_patch_thread
        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          @ssh.exec!("sudo /usr/local/bin/pharos-kubeadm-#{Pharos::KUBEADM_VERSION} upgrade apply #{Pharos::KUBE_VERSION} -y --ignore-preflight-errors=all --allow-experimental-upgrades --config #{tmp_file}")
        end
        dns_patch_thread.join

        logger.info { "Control plane upgrade succeeded!" }
      end

      # Hack to make coredns work without multi-arch enabled image repository
      #
      # @return [Thread]
      def create_dns_patch_thread
        api_client = kube_session.resource_client('extensions/v1beta1')
        Thread.new {
          begin
            sleep 5
            api_client.patch_deployment(
              'coredns',
              {
                spec: {
                  template: {
                    spec: {
                      containers: [
                        {
                          name: 'coredns',
                          image: "#{@config.image_repository}/coredns-#{@host.cpu_arch.name}:#{Pharos::COREDNS_VERSION}"
                        }
                      ]
                    }
                  }
                }
              },
              'kube-system'
            )
            logger.debug { "CoreDNS patch succeeded!" }
          rescue => exc
            logger.debug { "CoreDNS patch failed (will retry after 5 secs): #{exc.message}" }
            sleep 5
            retry
          end
        }
      end

      # @return [Pharos::Kube::Session]
      def kube_session
        Pharos::Kube.session(@host.api_address)
      end
    end
  end
end
