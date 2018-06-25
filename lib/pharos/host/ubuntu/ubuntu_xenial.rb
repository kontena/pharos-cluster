# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuXenial < Ubuntu
      register_config 'ubuntu', '16.04'

      CRIO_VERSION = '1.10'
      DOCKER_VERSION = '1.13.1'
      CFSSL_VERSION = '1.2'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.docker? } }
      )

      register_component(
        name: 'cri-o', version: CRIO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.crio? } }
      )

      register_component(
        name: 'containerd', version: Pharos::CONTAINERD_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.containerd? } }
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
            DOCKER_VERSION: "#{DOCKER_VERSION}-0ubuntu1~16.04.2"
          )
        elsif crio?
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: CRIO_VERSION,
            CRICTL_VERSION: Pharos::CRICTL_VERSION,
            CRIO_STREAM_ADDRESS: host.peer_address,
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: cluster_config.image_repository
          )
        elsif containerd?
          exec_script(
            'configure-containerd.sh',
            CONTAINERD_VERSION: Pharos::CONTAINERD_VERSION,
            STREAM_ADDRESS: host.peer_address,
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: cluster_config.image_repository
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end
    end
  end
end
