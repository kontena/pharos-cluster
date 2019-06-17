# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuBionic < Ubuntu
      register_config 'ubuntu', '18.04'

      DOCKER_VERSION = '18.09'
      CFSSL_VERSION = '1.2'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cri-o', version: CRIO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'cri-o' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      # @return [Array<String>]
      def kubelet_args
        kubelet_args = super
        kubelet_args << "--cgroup-driver=#{crio_cgroup_manager}" if crio?

        kubelet_args
      end

      # @return [String]
      def crio_cgroup_manager
        current_crio_cgroup_manager || 'systemd'
      end

      def configure_container_runtime
        if docker?
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker.io',
            DOCKER_VERSION: DOCKER_VERSION,
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
            CRIO_CGROUP_MANAGER: crio_cgroup_manager,
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: config.image_repository,
            INSECURE_REGISTRIES: insecure_registries
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end

      def default_repositories
        [Pharos::Configuration::Repository.new(
          name: "pharos-kubernetes.list",
          key_url: "https://bintray-pk.pharos.sh/?username=bintray",
          contents: "deb https://dl.bintray.com/kontena/pharos-debian bionic main\n"
        )]
      end
    end
  end
end
