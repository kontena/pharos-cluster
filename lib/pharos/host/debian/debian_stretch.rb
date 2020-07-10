# frozen_string_literal: true

require_relative 'debian'

module Pharos
  module Host
    class DebianStretch < Debian
      register_config 'debian', '9'

      CFSSL_VERSION = '1.2'
      DOCKER_VERSION = '19.03'

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      register_component(
        name: 'docker-ce', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'containerd', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'containerd' } }
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
        elsif containerd?
          exec_script(
            'configure-containerd.sh',
            CONTAINERD_VERSION: CONTAINERD_VERSION,
            INSECURE_REGISTRIES: insecure_registries
          )
        else
          raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}"
        end
      end

      def configure_container_runtime_safe?
        return true if custom_docker?

        if docker?
          result = transport.exec("dpkg-query --show docker-ce")
          return true if result.error? # docker not installed
          return true if result.stdout.split("\t")[1].to_s.start_with?("5:#{DOCKER_VERSION}")
        end

        false
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
            key_url: "https://download.docker.com/linux/debian/gpg",
            contents: "deb https://download.docker.com/linux/debian stretch stable\n"
          )
        ]
      end
    end
  end
end
