module Kuntena::Services
  class ConfigureClient

    def initialize(ssh, host: )
      @ssh = ssh
      @host = host
    end

    def call
      config_file = File.join(Dir.home, '.kube', @host)
      config_data = ''
      code = @ssh.exec("sudo cat /etc/kubernetes/admin.conf") do |type, data|
        config_data << data
      end
      if code == 0
        File.write(config_file, config_data.gsub(/(server: https:\/\/)(.+)(:6443)/, "\\1#{@host}\\3"))
      end

      code
    end
  end
end