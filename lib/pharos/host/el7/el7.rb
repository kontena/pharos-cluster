# frozen_string_literal: true

module Pharos
  module Host
    class El7 < Configurer
      DOCKER_VERSION = '1.13.1'
      CFSSL_VERSION = '1.2'

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, 'scripts', *path)
      end

      def install_essentials
        exec_script('configure-essentials.sh')
      end

      def configure_repos
        exec_script('repos/pharos_centos7.sh')
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

      # @return [Array<String>]
      def kubelet_args
        ['--cgroup-driver=systemd']
      end

      # @return [String] repository name to use with --enable-repo yum option
      def docker_repo_name
        abstract_method!
      end

      def configure_container_runtime
        if docker?
          exec_script(
            'configure-docker.sh',
            DOCKER_VERSION: DOCKER_VERSION,
            DOCKER_REPO_NAME: docker_repo_name,
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif custom_docker?
          exec_script(
            'configure-docker.sh',
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif crio?
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: Pharos::CRIO_VERSION,
            CRIO_STREAM_ADDRESS: '127.0.0.1',
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: config.image_repository,
            INSECURE_REGISTRIES: insecure_registries
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end

      def configure_container_runtime_safe?
        return true if custom_docker?

        if docker?
          return true if ssh.exec("rpm -qi docker").error? # docker not installed
          return true if ssh.exec("rpm -qi docker-#{DOCKER_VERSION}").success?
        elsif crio?
          return true if ssh.exec("rpm -qi cri-o").error? # cri-o not installed
          return true if ssh.exec("rpm -qi cri-o-#{Pharos::CRIO_VERSION}").success?
        end

        false
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
