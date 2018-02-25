require_relative 'logging'

module Shokunin::Services
  class ValidateHost
    include Shokunin::Services::Logging

    class InvalidHostError < StandardError; end

    def initialize(host)
      @host = host
    end

    def call
      logger.info(@host.address) { "Connecting to host via SSH ..."}
      ssh = Shokunin::SSH::Client.for_host(@host)
      logger.info { "Validating distro and version ..."}
      if ssh.exec('grep "Ubuntu 16.04" /etc/issue') != 0
        logger.error { "Distribution is not supported"}
        raise InvalidHostError, "Distro not supported"
      end
    end
  end
end