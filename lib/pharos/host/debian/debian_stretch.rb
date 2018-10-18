# frozen_string_literal: true

require_relative 'debian'

module Pharos
  module Host
    class DebianStretch < Debian
      register_config 'debian', '9'

      CFSSL_VERSION = '1.2'

      register_component(
        name: 'cri-o', version: CRIO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'cri-o' } }
      )

      register_component(
        name: 'cfssl', version: CFSSL_VERSION, license: 'MIT',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      def configure_repos
        exec_script("repos/pharos_stretch.sh")
        exec_script('repos/update.sh')
      end

      def configure_container_runtime
        raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}" unless crio?

        exec_script(
          'configure-cri-o.sh',
          CRIO_VERSION: Pharos::CRIO_VERSION,
          CRIO_STREAM_ADDRESS: '127.0.0.1',
          CPU_ARCH: host.cpu_arch.name,
          IMAGE_REPO: cluster_config.image_repository
        )
      end

      def reset
        exec_script(
          "reset.sh",
          CRIO_VERSION: CRIO_VERSION
        )
      end
    end
  end
end
