# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuXenial < Ubuntu
      register_config 'ubuntu', '16.04'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      def configure_container_runtime
        if docker?
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker-ce',
            DOCKER_VERSION: DOCKER_VERSION,
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

      def reset
        exec_script(
          "reset.sh"
        )
      end

      def default_repositories
        [
          Pharos::Configuration::Repository.new(
            name: "pharos-kubernetes.list",
            key_url: "https://packages.cloud.google.com/apt/doc/apt-key.gpg",
            contents: "deb https://apt.kubernetes.io/ kubernetes-xenial main\n"
          ),
          Pharos::Configuration::Repository.new(
            name: "docker-ce.list",
            key_url: "https://download.docker.com/linux/ubuntu/gpg",
            contents: "deb https://download.docker.com/linux/ubuntu xenial stable\n"
          )
        ]
      end
    end
  end
end
