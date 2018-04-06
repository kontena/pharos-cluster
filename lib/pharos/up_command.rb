# frozen_string_literal: true

module Pharos
  class UpCommand < Pharos::Command
    option ['-c', '--config'], 'PATH', 'Path to config file (default: cluster.yml)', attribute_name: :config_yaml do |config_file|
      begin
        Pharos::YamlFile.new(File.realpath(config_file))
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist: %<path>s' % { path: config_file }
      end
    end

    option '--hosts-from-tf', 'PATH', 'Path to terraform output json' do |config_path|
      begin
        File.realpath(config_path)
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist: %<path>s' % { path: config_path }
      end
    end

    # @return [Pharos::YamlFile]
    def default_config_yaml
      if !$stdin.tty? && !$stdin.eof?
        Pharos::YamlFile.new($stdin, force_erb: true, override_filename: '<stdin>')
      else
        cluster_config = Dir.glob('cluster.{yml,yml.erb}').first
        signal_usage_error 'File does not exist: cluster.yml' if cluster_config.nil?
        Pharos::YamlFile.new(cluster_config)
      end
    end

    def execute
      puts pastel.green("==> Reading instructions ...")
      config_hash = load_config
      if hosts_from_tf
        puts pastel.green("==> Importing hosts from Terraform ...")
        config_hash['hosts'] ||= []
        config_hash['hosts'] += load_tf_json
      end
      config = validate_config(config_hash)
      configure(config)
    end

    # @return [Hash] hash presentation of cluster.yml
    def load_config
      config_yaml.load(ENV.to_h)
    end

    # @return [Array<Hash>] parsed hosts from terraform json output
    def load_tf_json
      tf_parser = Pharos::Terraform::JsonParser.new(File.read(hosts_from_tf))
      tf_parser.hosts
    end

    # @param config_hash [Hash] hash presentation of cluster.yml
    # @return [Pharos::Config]
    def validate_config(config_hash)
      schema_class = Pharos::ConfigSchema.build
      schema = schema_class.call(config_hash)
      unless schema.success?
        show_config_errors(schema.messages)
        exit 11
      end

      config = Pharos::Config.new(schema)
      addon_manager.validate(config.addons || {})

      config
    end

    # @param config [Pharos::Config]
    def configure(config)
      master_hosts = master_hosts(config)
      signal_usage_error 'No master hosts defined' if master_hosts.empty?
      signal_usage_error 'Only one host can be in master role' if master_hosts.size > 1

      begin
        start_time = Time.now
        puts pastel.green("==> Sharpening tools ...")
        load_phases
        puts pastel.green("==> Starting to craft cluster ...")
        validate_hosts(config)
        # set workdir to the same dir where config was loaded from
        # so that the certs etc. can be referenced more easily
        Dir.chdir(config_yaml.dirname) do
          handle_masters(master_hosts[0], config)
          handle_workers(master_hosts[0], worker_hosts(config), config)
          handle_addons(master_hosts[0], config.addons)
        end
        craft_time = Time.now - start_time
        puts pastel.green("==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})")
      ensure
        Pharos::SSH::Client.disconnect_all
      end
    end

    # @param secs [Integer]
    # @return [String]
    def humanize_duration(secs)
      [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
        if secs.positive?
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      }.compact.reverse.join(' ')
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new([__dir__ + '/addons/'])
    end

    def load_phases
      Dir.glob(__dir__ + '/phases/*.rb').each { |f| require(f) }
    end

    def show_config_errors(errors)
      puts "==> Invalid configuration file:"
      puts YAML.dump(errors)
    end

    # @param hosts [Array<Pharos::Config>]
    def validate_hosts(config)
      valid = true
      config.hosts.each do |host|
        log_host_header(host)
        begin
          Phases::ValidateHost.new(host, config).call
        rescue Pharos::InvalidHostError => exc
          puts "    - #{exc.message}"
          valid = false
        end
      end
      exit 1 unless valid
    end

    # @param config [Pharos::Config]
    # @return [Array<Pharos::Configuration::Node>]
    def master_hosts(config)
      config.hosts.select { |h| h.role == 'master' }
    end

    # @param config [Pharos::Config]
    # @return [Array<Pharos::Configuration::Node>]
    def worker_hosts(config)
      config.hosts.select { |h| h.role == 'worker' }
    end

    # @param master [Pharos::Configuration::Node]
    # @param features [Pharos::Config]
    def handle_masters(master, config)
      log_host_header(master)
      Phases::ConfigureHost.new(master).call
      Phases::ConfigureMaster.new(master, config).call
      Phases::ConfigureClient.new(master).call
      Phases::ConfigureDNS.new(master, config).call
      Phases::ConfigureNetwork.new(master, config.network).call
      Phases::ConfigureMetrics.new(master).call
      Phases::LabelNode.new(master, master).call
      Phases::StoreClusterYAML.new(master, config_yaml.read(ENV.to_h)).call
    end

    # @param master [Pharos::Configuration::Node]
    # @param nodes [Array<Pharos::Configuration::Node>]
    # @param config [Pharos::Config]
    def handle_workers(master, nodes, config)
      nodes.each do |node|
        log_host_header(node)
        begin
          Phases::ConfigureHost.new(node).call
          Phases::ConfigureKubelet.new(node, config).call
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
