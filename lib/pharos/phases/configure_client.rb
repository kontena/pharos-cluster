# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      REMOTE_FILE = "/etc/kubernetes/admin.conf"

      def call
        Dir.mkdir(config_dir, 0o700) unless Dir.exist?(config_dir)

        logger.info { "Fetching kubectl config ..." }
        config_data = remote_config_file.read
        File.chmod(0o600, config_file) if File.exist?(config_file)
        File.write(config_file, config_data.gsub(%r{(server: https://)(.+)(:6443)}, "\\1#{@config.api_endpoint}\\3"), perm: 0o600)
        logger.info { "Configuration saved to #{config_file}" }
      end

      def remote_config_file
        @ssh.file(REMOTE_FILE)
      end

      def config_dir
        Pharos::Kube.config_dir
      end

      def config_file
        Pharos::Kube.config_path(@config.api_endpoint)
      end
    end
  end
end
