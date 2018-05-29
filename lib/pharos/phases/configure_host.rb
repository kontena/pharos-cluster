# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      register_component(
        name: 'docker', version: Pharos::DOCKER_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'docker' } }
      )

      register_component(
        name: 'cri-o', version: Pharos::CRIO_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'cri-o' } }
      )

      register_component(
        name: 'crictl', version: Pharos::CRICTL_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.hosts.any? { |h| h.container_runtime == 'cri-o' } }
      )

      def call
        logger.info { "Configuring essential packages ..." }
        exec_script(
          'configure-essentials.sh',
          HTTP_PROXY: @host.http_proxy.to_s,
          SET_HTTP_PROXY: @host.http_proxy.nil? ? 'false' : 'true'
        )

        logger.info { "Configuring package repositories ..." }
        configure_repos

        logger.info { "Configuring netfilter ..." }
        exec_script('configure-netfilter.sh')

        if docker?
          logger.info { "Configuring container runtime (docker) packages ..." }
          exec_script(
            'configure-docker.sh',
            DOCKER_PACKAGE: 'docker.io',
            DOCKER_VERSION: "#{Pharos::DOCKER_VERSION}-0ubuntu1~16.04.2",
            HTTP_PROXY: @host.http_proxy.to_s
          )
        elsif crio?
          logger.info { "Configuring container runtime (cri-o) packages ..." }
          exec_script(
            'configure-cri-o.sh',
            CRIO_VERSION: Pharos::CRIO_VERSION,
            CRICTL_VERSION: Pharos::CRICTL_VERSION,
            CRIO_STREAM_ADDRESS: @host.peer_address,
            CPU_ARCH: @host.cpu_arch.name,
            IMAGE_REPO: @config.image_repository,
            HTTP_PROXY: @host.http_proxy.to_s
          )
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
