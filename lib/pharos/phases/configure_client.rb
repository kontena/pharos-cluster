# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      title "Configure kube client"

      def call
        fetch_kubeconfig
      end

      def config_dir
        File.join(Dir.home, '.pharos')
      end

      def fetch_kubeconfig
        Dir.mkdir(config_dir, 0o700) unless Dir.exist?(config_dir)
        config_file = File.join(config_dir, @host.address)

        logger.info { "Fetching kubectl config ..." }
        config_data = @ssh.file("/etc/kubernetes/admin.conf").read
        File.chmod(0o600, config_file) if File.exist?(config_file)
        File.write(config_file, config_data.gsub(%r{(server: https://)(.+)(:6443)}, "\\1#{@host.address}\\3"), perm: 0o600)
        logger.info { "Configuration saved to #{config_file}" }
      end
    end
  end
end
