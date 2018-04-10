# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      PHASE_TITLE = "Configure hosts"

      register_component(
        Pharos::Phases::Component.new(
          name: 'docker', version: Pharos::DOCKER_VERSION, license: 'Apache License 2.0'
        )
      )

      register_component(
        Pharos::Phases::Component.new(
          name: 'cri-o', version: Pharos::CRIO_VERSION, license: 'Apache License 2.0'
        )
      )

      def call
        logger.info { "Configuring essential packages ..." }
        exec_script('configure-essentials.sh')

        logger.info { "Configuring package repositories ..." }
        configure_repos

        logger.info { "Configuring netfilter ..." }
        exec_script('configure-netfilter.sh')

        if docker?
          logger.info { "Configuring container runtime (docker) packages ..." }
          exec_script('configure-docker.sh',
                      DOCKER_PACKAGE: 'docker.io',
                      DOCKER_VERSION: "#{Pharos::DOCKER_VERSION}-0ubuntu1~16.04.2")
        elsif crio?
          logger.info { "Configuring container runtime (cri-o) packages ..." }
          exec_script('configure-cri-o.sh',
                      CRIO_VERSION: Pharos::CRIO_VERSION,
                      CRIO_STREAM_ADDRESS: @host.private_address ? @host.private_address : @host.address,
                      CPU_ARCH: @host.cpu_arch.name)
        else
          raise Pharos::Error, "Unknown container runtime: #{@host.container_runtime}"
        end
      end

      def configure_repos
        exec_script('repos/cri-o.sh') if crio?
        exec_script('repos/kube.sh')
        exec_script('repos/update.sh')
      end

      # @param script [String]
      # @param vars [Hash]
      def crio?
        @host.container_runtime == 'cri-o'
      end

      def docker?
        @host.container_runtime == 'docker'
      end
    end
  end
end
