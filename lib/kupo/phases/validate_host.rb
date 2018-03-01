require_relative 'logging'

module Kupo::Phases
  class ValidateHost
    include Kupo::Phases::Logging

    def initialize(host)
      @host = host
    end

    def call
      logger.info(@host.address) { "Connecting to host via SSH ..."}
      ssh = Kupo::SSH::Client.for_host(@host)
      logger.info { "Validating distro and version ..."}
      if ssh.exec('grep "Ubuntu 16.04" /etc/issue') != 0
        logger.error { "Distribution is not supported"}
        raise Kupo::InvalidHostError, "Distro not supported"
      end
    end
  end
end