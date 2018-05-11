# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      def call
        configurer = @host.configurer(@ssh)

        logger.info { "Configuring essential packages ..." }
        configurer.install_essentials

        logger.info { "Configuring package repositories ..." }
        configurer.configure_repos

        logger.info { "Configuring netfilter ..." }
        configurer.configure_netfilter

        logger.info { "Configuring container runtime (docker) packages ..." }
        configurer.configure_container_runtime
      end
    end
  end
end
