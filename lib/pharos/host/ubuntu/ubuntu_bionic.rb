# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuBionic < Ubuntu
      register_config 'ubuntu', '18.04'

      DOCKER_VERSION = '17.12.1'
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
        exec_script("repos/pharos_bionic.sh")
        exec_script('repos/update.sh')
      end

      def configure_container_runtime
        if docker?
          insecure_registries = cluster_config.container_runtime.insecure_registries.to_json.inspect
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker.io',
            DOCKER_VERSION: "#{DOCKER_VERSION}-0ubuntu1",
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif custom_docker?
          insecure_registries = cluster_config.container_runtime.insecure_registries.to_json.inspect
          exec_script(
            'configure-docker.sh',
            INSECURE_REGISTRIES: insecure_registries
          )
        elsif crio?
          insecure_registries = cluster_config.container_runtime.insecure_registries.map(&:inspect).join(",").inspect
          puts "********* #{insecure_registries}"
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: Pharos::CRIO_VERSION,
            CRIO_STREAM_ADDRESS: '127.0.0.1',
            CPU_ARCH: host.cpu_arch.name,
            IMAGE_REPO: cluster_config.image_repository,
            INSECURE_REGISTRIES: insecure_registries
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end
    end
  end
end
