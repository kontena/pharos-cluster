module Kontadm::Services
  class ConfigureHost

    def initialize(host)
      @host = host
    end

    def call
      ssh = Kontadm::SSH::Client.for_host(@host)
      file = File.realpath(File.join(__dir__, '..', 'scripts/init-host.sh'))
      ssh.upload(file, '/tmp/init-host.sh')
      ssh.exec('sudo /tmp/init-host.sh')
    end
  end
end