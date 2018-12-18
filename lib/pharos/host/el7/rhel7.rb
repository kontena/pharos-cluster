# frozen_string_literal: true

require_relative 'el7'

module Pharos
  module Host
    class Rhel7 < El7
      register_config 'rhel', '7.4'
      register_config 'rhel', '7.5'
      register_config 'rhel', '7.6'

      DOCKER_VERSION = '1.13.1'
      CFSSL_VERSION = '1.2'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cri-o', version: Pharos::CRIO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'cri-o' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      def docker_repo_name
        'rhel-7-server-extras-rpms'
      end
    end
  end
end
