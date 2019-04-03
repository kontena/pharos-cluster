# frozen_string_literal: true

module Pharos
  class RebootCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    options :filtered_hosts, :tf_json, :yes?

    def execute
      Dir.chdir(config_yaml.dirname) do
        filtered_hosts.size == load_config.hosts.size ? reboot_all : reboot_hosts
      end
    end

    def reboot_all
      confirm_yes!("==> Do you really want to reboot all of the hosts in the cluster?".bright_yellow, default: false)
      reboot_hosts
    end

    def reboot_hosts
      start_time = Time.now

      master_hosts = filtered_hosts.select(&:master?).reject(&:local?)
      worker_hosts = filtered_hosts.select(&:worker?).reject(&:local?)
      local_host   = filtered_hosts.select(&:local?).first

      original_hosts = load_config.hosts.dup
      load_config.hosts.keep_if { |host| host.master? || filtered_hosts.include?(host) }
      cluster_manager.gather_facts

      unless local_host.nil?
        puts "  " + ("!" * 76).red
        puts "    The host will remain cordoned (workloads will not be scheduled on it) after the reboot".red
        puts "    To uncordon, you must use: ".red + "pharos exec #{@config_options.join(' ') if @config_options} -r master -f -- kubectl uncordon #{local_host}".cyan
        puts "  " + ("!" * 76).red
        confirm_yes!("Host #{local_host} is localhost. It will remain cordoned after reboot. Are you sure?".bright_yellow, default: false)
      end

      unless master_hosts.empty?
        master_hosts.each.with_index(1) do |master, master_no|
          puts "==> Rebooting master #{master_no}/#{master_hosts.size}".green
          cluster_manager.apply_reboot_hosts([master])
        end
        puts "==> Resharpening tools ...".green
        load_config.hosts.keep_if(&:master?)
        cluster_manager.gather_facts
      end

      unless worker_hosts.empty?
        if original_hosts.count(&:worker?) / worker_hosts.size < 2
          worker_hosts.each_slice((worker_hosts.size / 2.to_f).ceil) do |slice|
            puts "==> Rebooting #{slice.size} worker node#{'s' if slice.size > 1} ...".green
            cluster_manager.apply_reboot_hosts(slice)
          end
        else
          puts "==> Rebooting #{worker_hosts.size} worker node#{'s' if worker_hosts.size > 1} ...".green
          cluster_manager.apply_reboot_hosts(worker_hosts)
        end
      end

      unless local_host.nil?
        puts "==> Rebooting localhost".green

        cluster_manager.apply_reboot_hosts([local_host])
      end

      reboot_time = Time.now - start_time
      puts "==> Rebooted #{filtered_hosts.size} node#{'s' if filtered_hosts.size > 1}! (took #{humanize_duration(reboot_time.to_i)})".green
    end
  end
end
