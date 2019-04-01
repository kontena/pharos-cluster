# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      def call
        unless @host.environment.nil? || @host.environment.empty?
          logger.info { "Updating environment file ..." }
          host_configurer.update_env_file
          coordinated_reconnect
        end

        logger.info { "Configuring script helpers ..." }
        host_configurer.configure_script_library

        logger.info { "Configuring essential packages ..." }
        host_configurer.install_essentials

        logger.info { "Configuring package repositories ..." }
        host_configurer.configure_repos

        logger.info { "Configuring netfilter ..." }
        host_configurer.configure_netfilter

        configure_container_runtime
      end

      def configure_container_runtime
        logger.info { "Configuring container runtime (#{@host.container_runtime}) packages ..." }
        host_configurer.configure_container_runtime
      end

      def coordinated_reconnect
        bastioned_hosts = @config.hosts.select { |host| host.bastion && host.bastion.address == @host.address }
        if bastioned_hosts.size > 0
          logger.info "Waiting for bastioned hosts to disconnect ..."
          sleep 0.1 until bastioned_hosts.all? { |host| !host.transport.connected? }
          logger.info "All bastioned hosts are disconnected."
        end
        @host.transport.disconnect

        if @config.hosts.any? { |host| !host.bastion.nil? }
          mutex.synchronize do
            unless cluster_context['configure-host:all-disconnected']
              logger.info "Coordinating reconnect..."
              sleep 0.1 until @config.hosts.all? { |host| !host.transport.connected? }
            end

            cluster_context['configure-host:all-disconnected'] = true
          end
        end

        logger.info "Reconnecting ..."
        @host.transport.connect
      end
    end
  end
end
