# frozen_string_literal: true

require_relative 'configurer'

module Pharos
  module Host
    class UbuntuXenial < Configurer
      CRIO_VERSION = '1.10'
      DOCKER_VERSION = '1.13.1'
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

      def install_essentials
        exec_script('configure-essentials.sh')
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
            CRIO_STREAM_ADDRESS: host.peer_address,
            CPU_ARCH: host.cpu_arch.name
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end
    end
  end
end