# frozen_string_literal: true

require 'singleton'

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      def call
        unless @host.environment.nil? || @host.environment.empty?
          logger.info { "Updating environment file ..." }
          host_configurer.update_env_file
        end

        logger.info { "Configuring script helpers ..." }
        host_configurer.configure_script_library

        logger.info { "Configuring essential packages ..." }
        host_configurer.install_essentials

        logger.info { "Configuring package repositories ..." }
        host_configurer.configure_repos

        logger.info { "Configuring netfilter ..." }
        host_configurer.configure_netfilter

        if @host.new?
          logger.info { "Configuring container runtime (#{@host.container_runtime}) packages ..." }
          host_configurer.configure_container_runtime
        else
          mutex.synchronize {
            if master_healthy?
              logger.info { "Draining node ..." }
              master_ssh.exec!("kubectl drain --force --ignore-daemonsets --delete-local-data #{@host.hostname}")
            end
            logger.info { "Reconfiguring container runtime (#{@host.container_runtime}) packages ..." }
            host_configurer.configure_container_runtime
            if master_healthy?
              logger.info { "Uncordoning node ..." }
              master_ssh.exec!("kubectl uncordon #{@host.hostname}")
            end
          }
        end
      end

      def master_ssh
        ssh_manager.client_for(@master)
      end

      def master_healthy?
        @master.master_sort_score == 0
      end
    end
  end
end
