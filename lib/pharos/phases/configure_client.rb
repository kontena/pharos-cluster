# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureClient < Base

      def call
        Dir.mkdir(config_dir, 0o700) unless Dir.exist?(config_dir)
        config_file = File.join(config_dir, @master.address)
        logger.info { "Fetching kubectl config ..." }
        config_data = @ssh.read_file("/etc/kubernetes/admin.conf")
        File.chmod(0o600, config_file) if File.exist?(config_file)
        File.write(config_file, config_data.gsub(%r{(server: https://)(.+)(:6443)}, "\\1#{@master.address}\\3"), perm: 0o600)
        logger.info { "Configuration saved to #{config_file}" }
      end

      def config_dir
        File.join(Dir.home, '.pharos')
      end
    end
  end
end
