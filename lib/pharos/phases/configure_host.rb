# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      ROLLOUT_PERCENTAGE = 10

      def call
        unless @host.environment.nil? || @host.environment.empty?
          logger.info "Updating environment file ..."
          host_configurer.update_env_file
        end

        logger.info "Configuring script helpers ..."
        host_configurer.configure_script_library

        logger.info "Configuring essential packages ..."
        host_configurer.install_essentials

        logger.info "Configuring package repositories ..."
        host_configurer.configure_repos

        logger.info "Configuring netfilter ..."
        host_configurer.configure_netfilter

        configure_container_runtime
      end

      def configure_container_runtime
        if @host.new? || host_configurer.configure_container_runtime_safe?
          logger.info "Configuring container runtime (#{@host.container_runtime}) packages ..."
          host_configurer.configure_container_runtime!
        else
          throttled_work('reconfigure_with_drain', rollout_concurrency) do
            logger.info "Reconfiguration of container runtime (#{@host.container_runtime}) might affect workloads, switching to a safe mode ..."
            reconfigure_with_drain
          end
        end
      end

      # @return [Integer]
      def rollout_concurrency
        (@config.hosts.size * ROLLOUT_PERCENTAGE / 100).ceil
      end

      def reconfigure_with_drain
        if master_healthy?
          logger.info "Draining node ..."
          begin
            drain_host
          rescue Pharos::ExecError
            drain_host!
          end
        else
          logger.warn "Cannot drain node because control-plane is not healthy ..."
        end

        logger.info "Waiting for volume umounts ..."
        sleep 1 until @host.transport.exec("sudo mount | grep /var/lib/kubelet/plugins").error?

        logger.info "Reconfiguring container runtime (#{@host.container_runtime}) packages ..."
        host_configurer.configure_container_runtime!

        return unless master_healthy?

        logger.info "Uncordoning node ..."
        sleep 1 until master_host.transport.exec("kubectl uncordon #{@host.hostname}").success?
        logger.info "Waiting for node to be ready ..."
        sleep 10 until master_host.transport.exec("kubectl get node #{@host.hostname} -o jsonpath=\"{range @.status.conditions[*]}{@.type}={@.status};{end}\" | grep 'Ready=True'").success?
      end

      def drain_host
        master_host.transport.exec!("kubectl drain --force --timeout=120s --ignore-daemonsets --delete-local-data #{@host.hostname}")
      end

      def drain_host!
        master_host.transport.exec!("kubectl drain --force --grace-period=0 --ignore-daemonsets --delete-local-data #{@host.hostname}")
      end

      def master_healthy?
        master_host.master_sort_score.zero?
      end
    end
  end
end
