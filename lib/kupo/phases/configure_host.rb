# frozen_string_literal: true

require_relative 'base'

module Kupo::Phases
  class ConfigureHost < Base
    CRIO_VERSION = '1.9'
    KUBE_VERSION = '1.9.4'
    DOCKER_VERSION = '1.13.1'

    register_component(
      Kupo::Phases::Component.new(
        name: 'docker', version: DOCKER_VERSION, license: 'Apache License 2.0'
      )
    )

    register_component(
      Kupo::Phases::Component.new(
        name: 'cri-o', version: CRIO_VERSION, license: 'Apache License 2.0'
      )
    )

    register_component(
      Kupo::Phases::Component.new(
        name: 'kubernetes', version: KUBE_VERSION, license: 'Apache License 2.0'
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
                    docker_package: 'docker.io',
                    docker_version: "#{DOCKER_VERSION}-0ubuntu1~16.04.2")
      elsif crio?
        logger.info { "Configuring container runtime (cri-o) packages ..." }
        exec_script('configure-cri-o.sh',
                    crio_version: CRIO_VERSION,
                    host: @host)
      else
        raise Kupo::Error, "Unknown container runtime: #{@host.container_runtime}"
      end

      logger.info { "Configuring Kubernetes packages ..." }
      exec_script(
        'configure-kube.sh',
        kube_version: KUBE_VERSION,
        kubeadm_version: ENV['KUBEADM_VERSION'] || KUBE_VERSION,
        arch: @host.cpu_arch.name
      )
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
