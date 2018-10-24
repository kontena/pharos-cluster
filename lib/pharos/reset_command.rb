# frozen_string_literal: true

module Pharos
  class ResetCommand < Pharos::Command
    parameter '[HOST] ...', "list of host addresses to reset"
    option '--[no-]drain', :flag, "enable or disable node drain before reset", default: true
    option '--[no-]delete', :flag, "enable or disable node delete before reset", default: true

    options :filtered_hosts, :yes?

    def execute
      puts pastel.bright_green("==> KONTENA PHAROS v#{Pharos::VERSION} (Kubernetes v#{Pharos::KUBE_VERSION})")

      hosts =
        if host_list.empty?
          filtered_hosts
        else
          load_config.hosts.select { |host| host_list.include?(host.address) }
        end

      if hosts.empty?
        warn "no hosts found"
        exit 1
      end

      Dir.chdir(config_yaml.dirname) do
        return reset_all if hosts.size == load_config.hosts.size
        reset_hosts(hosts)
      end
      cluster_manager.disconnect
    rescue Pharos::ConfigError => exc
      warn "==> #{exc}"
      exit 11
    rescue StandardError => ex
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{ex.class.name} : #{ex.message}"
      exit 1
    end

    def reset_hosts(hosts)
      remaining_hosts = load_config.hosts - hosts
      if remaining_hosts.none?(&:master?)
        signal_error 'There would be no master hosts left in the cluster after the reset. Reset the whole cluster by running this command without host filters.'
      elsif hosts.size > 1
        confirm_yes!(pastel.bright_yellow("==> Do you really want to reset #{hosts.size} hosts #{hosts.map(&:address).join(',')} (data may be lost)?"))
      else
        confirm_yes!(pastel.bright_yellow("==> Do you really want to reset the host #{hosts.first.address} (data may be lost)?"))
      end

      start_time = Time.now
      puts pastel.green("==> Starting to reset hosts ...")
      cluster_manager.apply_reset_hosts(hosts, drain: drain?, delete: delete?)
      reset_time = Time.now - start_time
      puts pastel.green("==> Hosts have been reset! (took #{humanize_duration(reset_time.to_i)})")
    end

    def reset_all
      confirm_yes!(pastel.bright_yellow("==> Do you really want to reset all hosts in the cluster (reset will wipe configuration & data from all hosts)?"))

      start_time = Time.now

      puts pastel.green("==> Starting to reset cluster ...")
      cluster_manager.apply_reset_all
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

    def ssh
      @ssh ||= Pharos::SSH::Manager.new.client_for(master_host)
    end

    # @return [Pharos::Config]
    def master_host
      @master_host ||= load_config.master_host
    end
  end
end
