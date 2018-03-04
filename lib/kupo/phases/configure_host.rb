require_relative 'base'

module Kupo::Phases
  class ConfigureHost < Base

    register_component(Kupo::Phases::Component.new(
      name: 'docker-ce', version: '17.03.2', license: 'Apache License 2.0'
    ))
    register_component(Kupo::Phases::Component.new(
      name: 'kubernetes', version: '1.9.3', license: 'Apache License 2.0'
    ))

    def initialize(host)
      @host = host
      @ssh = Kupo::SSH::Client.for_host(@host)
    end

    def call
      logger.info { "Configuring essential packages ..." }
      exec_script('configure-essentials.sh')
      logger.info { "Configuring netfilter ..." }
      exec_script('configure-netfilter.sh')
      logger.info { "Configuring container runtime packages ..." }
      exec_script('configure-docker.sh')
      logger.info { "Configuring Kubernetes packages ..." }
      exec_script('configure-kube.sh')
    rescue Kupo::Error => exc
      logger.error { exc.message }
    end

    def exec_script(script)
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      tmp_file = File.join('/tmp', SecureRandom.hex(16))
      @ssh.upload(file, tmp_file)
      code = @ssh.exec("sudo #{tmp_file}") do |type, data|
        remote_output(type, data)
      end
      @ssh.exec("sudo rm #{tmp_file}")
      if code != 0
        raise Kupo::Error, "Script execution failed: #{script}"
      end
    end
  end
end