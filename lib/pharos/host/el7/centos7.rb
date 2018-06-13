# frozen_string_literal: true

require_relative 'el7'

module Pharos
  module Host
    class Centos7 < El7
      register_config 'centos', '7'

      register_component(
        name: 'docker', version: El7::DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.docker? } }
      )

      register_component(
        name: 'containerd', version: El7::CONTAINERD_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.containerd? } }
      )

      register_component(
        name: 'cfssl', version: El7::CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )
    end
  end
end
