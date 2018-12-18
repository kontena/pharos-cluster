# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuXenial < Ubuntu
      register_config 'ubuntu', '16.04'

      DOCKER_VERSION = '18.06.1'
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

      def configure_repos
        exec_script("repos/pharos_xenial.sh")
        exec_script('repos/update.sh')
      end

      def configure_container_runtime
        if docker?
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker.io',
            DOCKER_VERSION: "#{DOCKER_VERSION}-0ubuntu1~16.04.2",
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif custom_docker?
          exec_script(
            'configure-docker.sh',
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif crio?
          can_pull = can_pull? # needs to be checked before configure
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: Pharos::CRIO_VERSION,
            CRIO_STREAM_ADDRESS: '127.0.0.1',
            CRIO_CGROUP_MANAGER: 'cgroupfs',
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: config.image_repository,
            INSECURE_REGISTRIES: insecure_registries
          )
          cleanup_crio! unless can_pull
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end

      def reset
        exec_script(
          "reset.sh",
          CRIO_VERSION: CRIO_VERSION
        )
      end
    end
  end
end
