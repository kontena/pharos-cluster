# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuXenial < Ubuntu
      register_config 'ubuntu', '16.04'

      DOCKER_VERSION = '17.03.2'
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
        exec_script('repos/cri-o.sh') if crio?
        exec_script("repos/pharos_xenial.sh")
        exec_script('repos/update.sh')
      end

      def configure_container_runtime
        if docker?
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker.io',
            DOCKER_VERSION: "#{DOCKER_VERSION}-0ubuntu2~16.04.1"
          )
        elsif crio?
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: Pharos::CRIO_VERSION,
            CRIO_STREAM_ADDRESS: host.peer_address,
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: cluster_config.image_repository
          )
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
