module Shokunin
  class UpCommand < Shokunin::Command

    option ['-c', '--config'], 'PATH', 'Path to config file', default: 'cluster.yml'

    def execute
      begin
        config_file = File.realpath(config)
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist'
      end

      config = load_config(config_file)

      master_hosts = master_hosts(config)
      signal_usage_error 'No master hosts defined' if master_hosts.size == 0
      signal_usage_error 'Only one host can be in master role' if master_hosts.size > 1

      begin
        validate_hosts(config.hosts)

        handle_masters(master_hosts[0], config.features)
        handle_workers(master_hosts[0], worker_hosts(config))
      ensure
        Shokunin::SSH::Client.disconnect_all
      end
    end

    # @param config_file [String]
    # @return [Shokunin::Config]
    def load_config(config_file)
      yaml = YAML.load(File.read(config_file))
      if yaml.is_a?(String)
        signal_usage_error "File #{config_file} is not in YAML format"
        exit 10
      end
      schema = Shokunin::ConfigSchema.call(yaml)
      unless schema.success?
        show_config_errors(schema.messages)
        exit 11
      end
      Shokunin::Config.new(schema)
    end

    def show_config_errors(errors)
      puts "==> Invalid configuration file:"
      puts YAML.dump(errors)
    end

    # @param hosts [Array<Shokunin::Configuration::Node>]
    def validate_hosts(hosts)
      valid = true
      hosts.each do |host|
        log_host_header(host)
        begin
          Shokunin::Services::ValidateHost.new(host).call
        rescue Shokunin::Services::ValidateHost::InvalidHostError => exc
          puts "    - #{exc.message}"
          valid = false
        end
      end
      exit 1 unless valid
    end

    # @param config [Shokunin::Config]
    # @return [Array<Shokunin::Configuration::Node>]
    def master_hosts(config)
      config.hosts.select { |h| h.role == 'master' }
    end

    # @param config [Shokunin::Config]
    # @return [Array<Shokunin::Configuration::Node>]
    def worker_hosts(config)
      config.hosts.select { |h| h.role == 'worker' }
    end

    # @param master [Shokunin::Configuration::Node]
    # @param features [Shokunin::Configuration::Features]
    def handle_masters(master, features)
      log_host_header(master)
      Shokunin::Services::ConfigureHost.new(master).call
      Shokunin::Services::ConfigureMaster.new(master).call
      Shokunin::Services::ConfigureClient.new(master).call
      Shokunin::Services::ConfigureNetwork.new(master, features.network).call
      Shokunin::Services::ConfigureKured.new(master, features.host_updates).call
      Shokunin::Services::ConfigureMetrics.new(master).call
    end

    # @param master [Shokunin::Configuration::Node]
    # @param nodes [Array<Shokunin::Configuration::Node>]
    def handle_workers(master, nodes)
      nodes.each do |node|
        log_host_header(node)
        begin
          Shokunin::Services::ConfigureHost.new(node).call
          Shokunin::Services::JoinNode.new(node, master).call
        end
      end
    end

    def log_host_header(host)
      puts pastel.cyan("==> #{host.role}: #{host.address}")
    end
  end
end
