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
      logger.info { "Fetching kubectl config ..." }
      config_data = ssh.file_contents("/etc/kubernetes/admin.conf")
      if config_data.nil?
        logger.error { "Failed to fetch configuration file via SSH" }
        raise "Failed to configure client"
      else
        File.write(config_file, config_data.gsub(/(server: https:\/\/)(.+)(:6443)/, "\\1#{@master.address}\\3"))
        logger.info { "Configuration saved to #{config_file}"}
      end
    end
  end
end