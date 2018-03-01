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
      logger.info { "Configuring netfilter ..." }
      exec_script('configure-netfilter.sh')
      logger.info { "Configuring ntpd ..." }
      exec_script('configure-ntp.sh')
      logger.info { "Configuring container engine ..." }
      exec_script('configure-docker.sh')
      logger.info { "Configuring Kubernetes engine ..." }
      exec_script('configure-kube.sh')
    rescue Kupo::Error => exc
      logger.error { exc.message }
    end

    def exec_script(script)
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      tmp_file = File.join('/tmp', SecureRandom.hex(16))
      @ssh.upload(file, tmp_file)
      code = @ssh.exec("sudo #{tmp_file} && sudo rm #{tmp_file}") do |type, data|
        logger.debug { data }
      end
      if code != 0
        raise Kupo::Error, "Script execution failed: #{script}"
      end
    end
  end
end