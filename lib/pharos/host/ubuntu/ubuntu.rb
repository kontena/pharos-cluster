# frozen_string_literal: true

module Pharos
  module Host
    class Ubuntu < Configurer
      def install_essentials
        exec_script('configure-essentials.sh')
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

      def configure_container_runtime_safe?
        return true if custom_docker?

        if docker?
          result = ssh.exec("dpkg-query --show docker.io")
          return true if result.error? # docker not installed
          return true if result.stdout.split("\t")[1].to_s.start_with?(DOCKER_VERSION)
        elsif crio?
          result = ssh.exec("dpkg-query --show cri-o")
          return true if result.error? # cri-o not installed
          return true if result.stdout.split("\t")[1].to_s.start_with?(Pharos::CRIO_VERSION)
        end

        false
      end

      def reset
        exec_script("reset.sh")
      end
    end
  end
end
