module Kuntena::Services
  class ConfigureHost

    def initialize(ssh)
      @ssh = ssh
    end

    def call
      file = File.realpath(File.join(__dir__, '..', 'scripts/init-host.sh'))
      @ssh.upload(file, '/tmp/init-host.sh')
      @ssh.exec('sudo /tmp/init-host.sh')
    end
  end
end