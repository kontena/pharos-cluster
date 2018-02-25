require_relative 'logging'

module Shokunin::Services
  class ConfigureClient
    include Shokunin::Services::Logging

    def initialize(master)
      @master = master
    end

    def call
      ssh = Shokunin::SSH::Client.for_host(@master)
      config_file = File.join(Dir.home, '.kube', @master.address)
      config_data = ''
      logger.info { "Fetching kubectl config ..." }
      code = ssh.exec("sudo cat /etc/kubernetes/admin.conf") do |type, data|
        config_data << data if type == :stdout
      end
      if code == 0
        logger.info { "Configuration saved to #{config_file}"}
        File.write(config_file, config_data.gsub(/(server: https:\/\/)(.+)(:6443)/, "\\1#{@master.address}\\3"))
      else
        logger.error { "Failed to fetch configuration file via SSH" }
        raise "Failed to configure client"
      end
    end
  end
end