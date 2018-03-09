require_relative 'base'

module Kupo::Phases
  class ConfigureHost < Base

    register_component(Kupo::Phases::Component.new(
      name: 'cri-o', version: '1.9', license: 'Apache License 2.0'
    ))
    register_component(Kupo::Phases::Component.new(
      name: 'docker-ce', version: '17.03.2', license: 'Apache License 2.0'
    ))
    register_component(Kupo::Phases::Component.new(
      name: 'kubernetes', version: '1.9.3', license: 'Apache License 2.0'
    ))

    # @param host [Kupo::Configuration::Host]
    def initialize(host)
      @host = host
      @ssh = Kupo::SSH::Client.for_host(@host)
    end

    def call
      logger.info { "Configuring essential packages ..." }
      exec_script('configure-essentials.sh')

      logger.info { "Configuring netfilter ..." }
      exec_script('configure-netfilter.sh')

      if @host.container_runtime == 'docker'
        logger.info { "Configuring container runtime (docker) packages ..." }
        exec_script('configure-docker.sh', {
          docker_package: 'docker-ce',
          docker_version: '17.03.2~ce-0~ubuntu-xenial'
        })
      elsif @host.container_runtime == 'cri-o'
        logger.info { "Configuring container runtime (cri-o) packages ..." }
        exec_script('configure-cri-o.sh', {
          crio_version: '1.9'
        })
      end

      logger.info { "Configuring Kubernetes packages ..." }
      exec_script('configure-kube.sh', {
        kube_version: '1.9.3'
      })
    rescue Kupo::Error => exc
      logger.error { exc.message }
    end

    def exec_script(script, vars = {})
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      parsed_file = Kupo::Erb.new(File.read(file)).render(vars)
      ssh_exec_file(@ssh, StringIO.new(parsed_file))
    rescue Kupo::ScriptExecError
      raise Kupo::ScriptExecError, "Failed to execute #{script}"
    end
  end
end
