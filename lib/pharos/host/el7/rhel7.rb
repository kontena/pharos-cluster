# frozen_string_literal: true

require_relative 'el7'

module Pharos
  module Host
    class Rhel7 < El7
      register_config 'rhel', '7.4'
      register_config 'rhel', '7.5'
      register_config 'rhel', '7.6'
      register_config 'rhel', '7.7'
      register_config 'rhel', '7.8'

      register_component(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )
    end
  end
end
