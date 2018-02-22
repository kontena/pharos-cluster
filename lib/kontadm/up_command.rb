module Kontadm
  class UpCommand < Kontadm::Command

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

      validate_hosts(config.hosts)

      handle_masters(master_hosts[0], config.features)
      handle_workers(master_hosts[0], worker_hosts(config))
    end

    # @param config_file [String]
    # @return [Kontadm::Config]
    def load_config(config_file)
      yaml = YAML.load(File.read(config_file))
      if yaml.is_a?(String)
        signal_usage_error "File #{config_file} is not in YAML format"
        exit 10
      end
      schema = Kontadm::ConfigSchema.call(yaml)
      unless schema.success?
        show_config_errors(schema.messages)
        exit 11
      end
      Kontadm::Config.new(schema)
    end

    def show_config_errors(errors)
      puts "==> Invalid configuration file:"
      puts YAML.dump(errors)
    end

    # @param hosts [Array<Kontadm::Configuration::Node>]
    def validate_hosts(hosts)
      valid = true
      hosts.each do |host|
        begin
          puts "==> [#{host.address}] Validating host"
          Kontadm::Services::ValidateHost.new(host).call
        rescue Kontadm::Services::ValidateHost::InvalidHostError => exc
          puts "    - #{exc.message}"
          valid = false
        end
      end
      exit 1 unless valid
    end

    # @param config [Kontadm::Config]
    # @return [Array<Kontadm::Configuration::Node>]
    def master_hosts(config)
      config.hosts.select { |h| h.role == 'master' }
    end

    # @param config [Kontadm::Config]
    # @return [Array<Kontadm::Configuration::Node>]
    def worker_hosts(config)
      config.hosts.select { |h| h.role == 'worker' }
    end

    # @param master [Kontadm::Configuration::Node]
    # @param features [Kontadm::Configuration::Features]
    def handle_masters(master, features)
      puts "==> [#{master.address}] Installing required packages"
      Kontadm::Services::ConfigureHost.new(master).call

      puts "==> [#{master.address}] Configuring control plane"
      Kontadm::Services::ConfigureMaster.new(master).call

      puts "==> [#{master.address}] Importing kubectl config"
      Kontadm::Services::ConfigureClient.new(master).call

      puts "==> [#{master.address}] Configuring overlay network"
      Kontadm::Services::ConfigureNetwork.new(master, features.network).call

      puts "==> [#{master.address}] Configuring reboot daemon"
      Kontadm::Services::ConfigureKured.new(master, features.host_updates).call
    end

    # @param master [Kontadm::Configuration::Node]
    # @param nodes [Array<Kontadm::Configuration::Node>]
    def handle_workers(master, nodes)
      nodes.each do |node|
        begin
          puts "==> [#{node.address}] Installing required packages"
          Kontadm::Services::ConfigureHost.new(node).call
          puts "==> [#{node.address}] Joining node to the cluster"
          Kontadm::Services::JoinNode.new(node, master).call
        end
      end
    end
  end
end
