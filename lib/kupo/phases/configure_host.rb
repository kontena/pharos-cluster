# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ConfigureHost < Base
      register_component(
        Kupo::Phases::Component.new(
          name: 'docker', version: Kupo::DOCKER_VERSION, license: 'Apache License 2.0'
        )
      )

      register_component(
        Kupo::Phases::Component.new(
          name: 'cri-o', version: Kupo::CRIO_VERSION, license: 'Apache License 2.0'
        )
      )

      # @param host [Kupo::Configuration::Host]
      def initialize(host)
        @host = host
        @ssh = Kupo::SSH::Client.for_host(@host)
      end

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
                      DOCKER_VERSION: "#{Kupo::DOCKER_VERSION}-0ubuntu1~16.04.2")
        elsif crio?
          logger.info { "Configuring container runtime (cri-o) packages ..." }
          exec_script('configure-cri-o.sh',
                      CRIO_VERSION: Kupo::CRIO_VERSION,
                      CRIO_STREAM_ADDRESS: @host.private_address ? @host.private_address : @host.address,
                      CPU_ARCH: @host.cpu_arch.name)
        else
          raise Kupo::Error, "Unknown container runtime: #{@host.container_runtime}"
        end

        logger.info { "Preparing binary installation ..." }
        prepare_install
      end

      def configure_repos
        exec_script('repos/cri-o.sh') if crio?
        exec_script('repos/update.sh')
      end

      def prepare_install
        @ssh.exec!('sudo mkdir -p /opt/kontena/bin')
        install_script('/opt/kontena/bin/install-kube-bin.sh', 'install-kube-bin.sh')
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
