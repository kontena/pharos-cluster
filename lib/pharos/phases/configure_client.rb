# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureClient < Base
      def call
        fetch_kubeconfig
        create_join_command
      end

      def config_dir
        File.join(Dir.home, '.pharos')
      end

      def fetch_kubeconfig
        Dir.mkdir(config_dir, 0o700) unless Dir.exist?(config_dir)
        config_file = File.join(config_dir, @master.address)

        logger.info { "Fetching kubectl config ..." }
        config_data = @ssh.read_file("/etc/kubernetes/admin.conf")
        File.chmod(0o600, config_file) if File.exist?(config_file)
        File.write(config_file, config_data.gsub(%r{(server: https://)(.+)(:6443)}, "\\1#{@master.address}\\3"), perm: 0o600)
        logger.info { "Configuration saved to #{config_file}" }
      end

      def create_join_command
        logger.info { "Creating node bootstrap token ..." }
        @master.join_command = @ssh.exec!("sudo kubeadm token create --print-join-command").split(' ')
      end
    end
  end
end
