# frozen_string_literal: true

module Pharos
  class ResetCommand < Pharos::Command
    options :filtered_hosts, :yes?

    def execute
      puts pastel.bright_green("==> KONTENA PHAROS v#{Pharos.version} (Kubernetes v#{Pharos::KUBE_VERSION})")

      Dir.chdir(config_yaml.dirname) do
        filtered_hosts.size == load_config.hosts.size ? reset_all : reset_hosts
      end
      cluster_manager.disconnect
    end

    def reset_hosts
      remaining_hosts = load_config.hosts - filtered_hosts
      if remaining_hosts.none?(&:master?)
        signal_error 'There would be no master hosts left in the cluster after the reset. Reset the whole cluster by running this command without host filters.'
      elsif filtered_hosts.size > 1
        confirm_yes!(pastel.bright_yellow("==> Do you really want to reset #{filtered_hosts.size} hosts #{filtered_hosts.map(&:address).join(',')} (data may be lost)?"), default: false)
      else
        confirm_yes!(pastel.bright_yellow("==> Do you really want to reset the host #{filtered_hosts.first.address} (data may be lost)?"), default: false)
      end

      start_time = Time.now
      puts pastel.green("==> Starting to reset hosts ...")
      cluster_manager.apply_reset_hosts(filtered_hosts)
      reset_time = Time.now - start_time
      puts pastel.green("==> Hosts have been reset! (took #{humanize_duration(reset_time.to_i)})")
    end

    def reset_all
      confirm_yes!(pastel.bright_yellow("==> Do you really want to reset all hosts in the cluster (reset will wipe configuration & data from all hosts)?"), default: false)

      start_time = Time.now

      puts pastel.green("==> Starting to reset cluster ...")
      cluster_manager.apply_reset_hosts(load_config.hosts)
      reset_time = Time.now - start_time
      puts pastel.green("==> Cluster has been reset! (took #{humanize_duration(reset_time.to_i)})")
    end

    def cluster_manager
      @cluster_manager ||= ClusterManager.new(load_config, pastel: pastel).tap do |cluster_manager|
        puts pastel.green("==> Sharpening tools ...")
        cluster_manager.load
        cluster_manager.gather_facts
      end
    end
  end
end
