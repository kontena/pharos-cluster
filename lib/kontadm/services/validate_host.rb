module Kontadm::Services
  class ValidateHost

    class InvalidHostError < StandardError; end

    def initialize(host)
      @host = host
    end

    def call
      ssh = Kontadm::SSH::Client.for_host(@host)
      if ssh.exec('grep "Ubuntu 16.04" /etc/issue') != 0
        raise InvalidHostError, "Distro not supported"
      end
    end
  end
end