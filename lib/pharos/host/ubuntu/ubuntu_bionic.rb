# frozen_string_literal: true

require_relative 'ubuntu'

module Pharos
  module Host
    class UbuntuBionic < Ubuntu
      register_config 'ubuntu', '18.04'

      CRIO_VERSION = '1.10'
      DOCKER_VERSION = '17.12.1'
      CFSSL_VERSION = '1.2'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      def configure_container_runtime
        raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}" unless docker?

        exec_script(
          'configure-docker.sh',
          DOCKER_PACKAGE: 'docker.io',
          DOCKER_VERSION: "#{DOCKER_VERSION}-0ubuntu1"
        )
      end
    end
  end
end
