# frozen_string_literal: true

module Pharos
  module Host
    class El7 < Configurer
      DOCKER_VERSION = '19.03.6'
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
        host_repositories.each do |repo|
          repo_path = "/etc/yum.repos.d/#{repo.name}"
          transport.file(repo_path).write(repo.contents)
        end
        transport.exec!("sudo yum clean expire-cache")
      end

      def default_repositories
        [
          Pharos::Configuration::Repository.new(
            name: "kontena-pharos.repo",
            contents: <<~CONTENTS
              [kubernetes]
              name=Kubernetes
              baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
              enabled=1
              gpgcheck=1
              repo_gpgcheck=1
              gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
            CONTENTS
          ),
          Pharos::Configuration::Repository.new(
            name: "docker-ce.repo",
            contents: <<~CONTENTS
              [docker-ce]
              name=Docker CE Stable
              baseurl=https://download.docker.com/linux/centos/7/$basearch/stable
              enabled=1
              gpgcheck=1
              gpgkey=https://download.docker.com/linux/centos/gpg
            CONTENTS
          )
        ]
      end

      def configure_netfilter
        exec_script('configure-netfilter.sh')
      end

      def configure_cfssl
        exec_script(
          'configure-cfssl.sh',
          IMAGE: "docker.io/jakolehm/cfssl:0.1.1"
        )
      end

      # @return [Array<String>]
      def kubelet_args
        ['--cgroup-driver=cgroupfs']
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
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end

      def configure_container_runtime_safe?
        return true if custom_docker?

        if docker?
          return true if transport.exec("rpm -qi docker-ce").error? # docker not installed
          return true if transport.exec("rpm -qi docker-ce-#{DOCKER_VERSION}").success?
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

      def configure_firewalld
        exec_script("configure-firewalld.sh")
      end

      def reset
        exec_script("reset.sh")
      end
    end
  end
end
