# frozen_string_literal: true

module Kupo
  class UpCommand < Kupo::Command
    option ['-c', '--config'], 'PATH', 'Path to config file (default: cluster.yml)', attribute_name: :config_file do |config_path|
      begin
        File.realpath(config_path)
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist: %s' % config_path
      end
    end

    def default_config_file
      if !$stdin.tty? && !$stdin.eof?
        :stdin
      else
        begin
          File.realpath('cluster.yml')
        rescue Errno::ENOENT
          signal_usage_error 'File does not exist: cluster.yml'
        end
      end
    end

    def execute
      puts pastel.green("==> Reading instructions ...")
      configure(load_config(config_content))
    end
    def configure(config)
      master_hosts = master_hosts(config)
      signal_usage_error 'No master hosts defined' if master_hosts.empty?
      signal_usage_error 'Only one host can be in master role' if master_hosts.size > 1

      begin
        start_time = Time.now
        puts pastel.green("==> Sharpening tools ...")
        load_phases
        puts pastel.green("==> Starting to craft cluster ...")
        validate_hosts(config.hosts)
        # set workdir to the same dir where config was loaded from
        # so that the certs etc. can be referenced more easily
        Dir.chdir(File.dirname(config_file)) do
          handle_masters(master_hosts[0], config)
          handle_workers(master_hosts[0], worker_hosts(config))
          handle_addons(master_hosts[0], config.addons)
        end
        craft_time = Time.now - start_time
        puts pastel.green("==> Cluster has been crafted, kupo! (took #{humanize_duration(craft_time.to_i)})")
      ensure
        Kupo::SSH::Client.disconnect_all
      end
    end

    def humanize_duration(secs)
      [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      }.compact.reverse.join(' ')
    end

    # @return [String] configuration content
    def config_content
      config_file == :stdin ? $stdin.read : File.read(config_file)
    end

    # @param [String] configuration content
    # @return [Kupo::Config]
    def load_config(content)
      yaml = YAML.safe_load(content)
      if yaml.is_a?(String)
        signal_usage_error "File #{config_file} is not in YAML format"
        exit 10
      end
      schema_class = Kupo::ConfigSchema.build
      schema = schema_class.call(yaml)
      unless schema.success?
        show_config_errors(schema.messages)
        exit 11
      end

      config = Kupo::Config.new(schema)
      addon_manager.validate(config.addons)

      config
    end

    # @return [Kupo::AddonManager]
    def addon_manager
      @addon_manager ||= Kupo::AddonManager.new([
                                                  __dir__ + '/addons/'
                                                ])
    end

    def load_phases
      Dir.glob(__dir__ + '/phases/*.rb').each { |f| require(f) }
    end

    def show_config_errors(errors)
      puts "==> Invalid configuration file:"
      puts YAML.dump(errors)
    end

    # @param hosts [Array<Kupo::Configuration::Node>]
    def validate_hosts(hosts)
      valid = true
      hosts.each do |host|
        log_host_header(host)
        begin
          Phases::ValidateHost.new(host).call
        rescue Kupo::InvalidHostError => exc
          puts "    - #{exc.message}"
          valid = false
        end
      end
      exit 1 unless valid
    end

    # @param config [Kupo::Config]
    # @return [Array<Kupo::Configuration::Node>]
    def master_hosts(config)
      config.hosts.select { |h| h.role == 'master' }
    end

    # @param config [Kupo::Config]
    # @return [Array<Kupo::Configuration::Node>]
    def worker_hosts(config)
      config.hosts.select { |h| h.role == 'worker' }
    end

    # @param master [Kupo::Configuration::Node]
    # @param features [Kupo::Config]
    def handle_masters(master, config)
      log_host_header(master)
      Phases::ConfigureHost.new(master).call
      Phases::ConfigureKubelet.new(master).call
      Phases::ConfigureMaster.new(master, config).call
      Phases::ConfigureClient.new(master).call
      Phases::ConfigureDNS.new(master, config).call
      Phases::ConfigureNetwork.new(master, config.network).call
      Phases::ConfigureMetrics.new(master).call
      Phases::LabelNode.new(master, master).call
    end

    # @param master [Kupo::Configuration::Node]
    # @param nodes [Array<Kupo::Configuration::Node>]
    def handle_workers(master, nodes)
      nodes.each do |node|
        log_host_header(node)
        begin
          Phases::ConfigureHost.new(node).call
          Phases::ConfigureKubelet.new(node).call
          Phases::JoinNode.new(node, master).call
          Phases::LabelNode.new(node, master).call
        end
      end
    end

    def handle_addons(master, addon_configs)
      puts pastel.cyan("==> addons: #{master.address}")
      addon_manager.apply(master, addon_configs)
    end

    def log_host_header(host)
      puts pastel.cyan("==> #{host.role}: #{host.address}")
    end
  end
end
