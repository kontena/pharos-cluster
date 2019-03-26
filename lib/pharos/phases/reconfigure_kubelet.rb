# frozen_string_literal: true

module Pharos
  module Phases
    class ReconfigureKubelet < Pharos::Phase
      title "Reconfigure kubelet"

      on :all_hosts

      def call
        return if host.new?

        logger.info { 'Reconfiguring kubelet ...' }
        reconfigure_kubelet
      end

      def reconfigure_kubelet
        config = transport.file('/var/lib/kubelet/config.yaml')
        unless config.exist?
          logger.error "Cannot read existing configuration file, skipping reconfigure ..."
          return
        end
        org_config = config.read
        transport.exec!("sudo kubeadm upgrade node config --kubelet-version #{Pharos::KUBE_VERSION}")
        new_config = config.read
        return if new_config == org_config

        transport.exec!('sudo systemctl restart kubelet')
      end
    end
  end
end
