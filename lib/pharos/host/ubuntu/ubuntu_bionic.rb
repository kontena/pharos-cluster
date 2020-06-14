# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuBionic < Ubuntu
      register_config 'ubuntu', '18.04'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'containerd', version: CONTAINERD_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'containerd' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      # @return [Array<String>]
      def kubelet_args
        kubelet_args = super

        kubelet_args
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
            contents: "deb https://download.docker.com/linux/ubuntu bionic stable\n"
          )
        ]
      end
    end
  end
end
