# frozen_string_literal: true

module Pharos
  module Host
    class Debian < Configurer
      def install_essentials
        exec_script(
          'configure-essentials.sh'
        )
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

      def configure_firewalld
        exec_script("configure-firewalld.sh")
      end

      def reset
        exec_script("reset.sh")
      end

      def configure_repos
        host_repositories.each do |repo|
          repo_path = "/etc/apt/sources.list.d/#{repo.name}"
          next if transport.file(repo_path).exist?

          transport.exec!("sudo curl -fsSL #{repo.key_url} | apt-key add -") if repo.key_url
          transport.file(repo_path).write(repo.contents)
        end
        transport.exec!("DEBIAN_FRONTEND=noninteractive sudo apt-get update -y")
      end
    end
  end
end
