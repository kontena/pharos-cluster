require_relative 'logging'

module Shokunin::Services
  class ConfigureHost
    include Shokunin::Services::Logging

    def initialize(host)
      @host = host
      @ssh = Shokunin::SSH::Client.for_host(@host)
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
    rescue Shokunin::Error => exc
      logger.error { exc.message }
    end

    def exec_script(script)
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      @ssh.upload(file, "/tmp/exec-#{script}")
      code = @ssh.exec("sudo /tmp/exec-#{script}") do |type, data|
        logger.debug { data }
      end
      if code != 0
        raise Shokunin::Error, "Script execution failed: #{script}"
      end
    end
  end
end