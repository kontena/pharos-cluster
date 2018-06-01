# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      def call
        logger.info { "Configuring essential packages ..." }
        configure_script_library
        host_configurer.install_essentials

        logger.info { "Configuring package repositories ..." }
        host_configurer.configure_repos

        logger.info { "Configuring netfilter ..." }
        host_configurer.configure_netfilter

        logger.info { "Configuring container runtime (docker) packages ..." }
        host_configurer.configure_container_runtime
      end

      def configure_script_library
        path = "/usr/local/share/pharos"
        @ssh.exec("sudo mkdir -p #{path}")
        @ssh.file("#{path}/util.sh").write(
          File.read(File.join(__dir__, '..', 'scripts', 'pharos.sh'))
        )
      end
    end
  end
end
