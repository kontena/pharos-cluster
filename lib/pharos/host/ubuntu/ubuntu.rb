# frozen_string_literal: true

module Pharos
  module Host
    class Ubuntu < Configurer
      def install_essentials
        exec_script(
          'configure-essentials.sh',
          HTTP_PROXY: host.http_proxy.to_s,
          NO_PROXY: host.no_proxy.to_s
        )
      end

      def configure_repos
        exec_script('repos/cri-o.sh') if crio?
        exec_script('repos/kube.sh')
        exec_script('repos/update.sh')
      end

      def configure_netfilter
        exec_script('configure-netfilter.sh')
      end

      def configure_cfssl
        exec_script(
          'configure-cfssl.sh',
          ARCH: host.cpu_arch.name
        )
      end

      def ensure_kubelet(args)
        exec_script(
          'ensure-kubelet.sh',
          args
        )
      end

      def install_kube_packages(args)
        exec_script(
          'install-kube-packages.sh',
          args
        )
      end

      def upgrade_kubeadm(version)
        exec_script(
          "upgrade-kubeadm.sh",
          VERSION: version,
          ARCH: host.cpu_arch.name
        )
      end

      def reset
        exec_script("reset.sh")
      end
    end
  end
end
