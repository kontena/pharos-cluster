require_relative 'base'

module Kupo::Phases
  class ConfigureClient < Base

    # @param master [Kupo::Configuration::Host]
    def initialize(master)
      @master = master
      @ssh = Kupo::SSH::Client.for_host(@master)
    end

    def call
      Dir.mkdir(config_dir, 0700) unless Dir.exists?(config_dir)
      config_file = File.join(config_dir, @master.address)
      logger.info { "Fetching kubectl config ..." }
      config_data = @ssh.read_file("/etc/kubernetes/admin.conf")

      File.write(config_file, config_data.gsub(/(server: https:\/\/)(.+)(:6443)/, "\\1#{@master.address}\\3"))
      logger.info { "Configuration saved to #{config_file}"}
    end

    def config_dir
      File.join(Dir.home, '.kupo')
    end
  end
end
