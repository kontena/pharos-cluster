# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHost < Pharos::Phase
      title "Configure hosts"

      def configure_container_runtime
        Thread.current.abort_on_exception = true
        if @host.new? || host_configurer.configure_container_runtime_safe?
          logger.info { "Configuring container runtime (#{@host.container_runtime}) packages ..." }
          host_configurer.configure_container_runtime
        else
          logger.info { "Reconfiguration of container runtime (#{@host.container_runtime}) might affect workloads, switching to a safe mode ..." }
          mutex.synchronize do
            if master_healthy?
              logger.info { "Draining node ..." }
              begin
                drain_host
              rescue Pharos::ExecError
                drain_host!
              end
            end
            logger.info { "Reconfiguring container runtime (#{@host.container_runtime}) packages ..." }
            host_configurer.configure_container_runtime
            if master_healthy?
              logger.info { "Uncordoning node ..." }
              sleep 1 until master_host.transport.exec("kubectl uncordon #{@host.hostname}")
              logger.info { "Waiting for node to be ready ..." }
              sleep 10 until master_host.transport.exec("kubectl get nodes -o jsonpath=\"{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}\" | grep 'Ready=True'").success?
            end
          end
        end
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
