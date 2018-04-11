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
    rescue StandardError => ex
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{ex.class.name} : #{ex.message}"
      exit 1
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

      signal_usage_error 'No master hosts defined' if config.master_hosts.empty?
      signal_usage_error 'Only one host can be in master role' if config.master_hosts.size > 1

      config
    end

    # @param config [Pharos::Config]
    def configure(config)
      start_time = Time.now
      puts pastel.green("==> Sharpening tools ...")
      @phase_manager = Pharos::PhaseManager.new([__dir__ + '/phases/'],
        ssh_manager: ssh_manager,
        config: config,
      )
      addon_manager
      puts pastel.green("==> Starting to craft cluster ...")

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        handle_phases(config)
        handle_addons(master_host, config.addons)
      end

      craft_time = Time.now - start_time
      puts pastel.green("==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})")
      puts "    You can connect to the cluster with kubectl using:"
      puts "    export KUBECONFIG=~/.pharos/#{master_hosts[0].address}"

      ssh_manager.disconnect_all
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

    # @return [Pharos::SSH::Manager]
    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new([__dir__ + '/addons/'])
    end

    def show_config_errors(errors)
      puts "==> Invalid configuration file:"
      puts YAML.dump(errors)
    end

    def handle_phases(config)
      handle_phase(Phases::ValidateHost, config.hosts, ssh: true, parallel: true)
      handle_phase(Phases::ConfigureHost, config.hosts, ssh: true, parallel: true)

      handle_phase(Phases::ConfigureKubelet, config.worker_hosts, ssh: true, parallel: true) # TODO: also run this phase in parallel for the master nodes, if not doing an upgrade?

      handle_phase(Phases::ConfigureMaster, config.master_hosts, ssh: true, parallel: false)
      handle_phase(Phases::ConfigureClient, config.master_hosts, ssh: true, parallel: true)

      # master is now configured and can be used
      handle_phase(Phases::ConfigureDNS, [config.master_host], master: config.master_host)
      handle_phase(Phases::ConfigureNetwork, [config.master_host], master: config.master_host)
      handle_phase(Phases::ConfigureMetrics, [config.master_host], master: config.master_host)
      handle_phase(Phases::StoreClusterYAML, [config.master_host], master: config.master_host, config_content: config_yaml.read(ENV.to_h))
      handle_phase(Phases::ConfigureBootstrap, [config.master_host], ssh: true) # using `kubeadm token`, not the kube API

      handle_phase(Phases::JoinNode, config.worker_hosts, ssh: true, parallel: true)

      handle_phase(Phases::LabelNode, config.hosts, master: config.master_host, ssh: false, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe
    end

    def handle_phase(phase_class, hosts, **options)
      puts pastel.cyan("==> #{phase_class.title} @ #{hosts.join(' ')}")

      @phase_manager.apply(phase_class, hosts, **options)
    end

    def handle_addons(master, addon_configs)
      puts pastel.cyan("==> addons: #{master.address}")
      addon_manager.apply(master, addon_configs)
    end
  end
end
