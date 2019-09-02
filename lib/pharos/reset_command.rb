# frozen_string_literal: true

module Pharos
  class ResetCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    options :filtered_hosts, :tf_json, :yes?

    def execute
      puts "==> KONTENA PHAROS v#{Pharos.version} (Kubernetes v#{Pharos::KUBE_VERSION})".bright_green

      Dir.chdir(config_yaml.dirname) do
        filtered_hosts.size == load_config.hosts.size ? reset_all : reset_hosts
      end
      cluster_manager.disconnect
    end

    def reset_hosts
      remaining_masters = load_config.hosts.select(&:master?) - filtered_hosts.select(&:master?)
      if remaining_masters.empty?
        signal_error 'There would be no master hosts left in the cluster after the reset. Reset the whole cluster by running this command without host filters.'
      elsif filtered_hosts.size > 1
        confirm_yes!("==> Do you really want to reset #{filtered_hosts.size} hosts #{filtered_hosts.map(&:address).join(',')} (data may be lost)?".bright_yellow, default: false)
      else
        confirm_yes!("==> Do you really want to reset the host #{filtered_hosts.first.address} (data may be lost)?".bright_yellow, default: false)
      end

      start_time = Time.now
      puts "==> Starting to reset host#{'s' if filtered_hosts.size > 1} ...".green
      cluster_manager.apply_reset_hosts(filtered_hosts)
      reset_time = Time.now - start_time
      puts "==> #{filtered_hosts.size > 1 ? 'Hosts have' : 'Host has'} been reset! (took #{humanize_duration(reset_time.to_i)})".green
    end

    def reset_all
      confirm_yes!("==> Do you really want to reset all hosts in the cluster (reset will wipe configuration & data from all hosts)?".bright_yellow, default: false)

      start_time = Time.now

      puts "==> Starting to reset cluster ...".green
      cluster_manager.apply_reset_hosts(load_config.hosts)
      reset_time = Time.now - start_time
      puts "==> Cluster has been reset! (took #{humanize_duration(reset_time.to_i)})".green
    end
  end
end
