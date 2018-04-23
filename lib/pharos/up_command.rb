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

    option '--tf-json', 'PATH', 'Path to terraform output json' do |config_path|
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
      config_content = read_config
      if tf_json
        puts pastel.green("==> Importing configuration from Terraform ...")
        load_terraform(tf_json, config_hash)
      end

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        config = build_config(config_hash)
        configure(config, config_content: config_content)
      end
    rescue StandardError => ex
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{ex.class.name} : #{ex.message}"
      exit 1
    end

    # @return [Hash] hash presentation of cluster.yml
    def load_config
      config_yaml.load(ENV.to_h)
    end

    # @return [String] raw cluster.yml
    def read_config
      config_yaml.read(ENV.to_h)
    end

    # @param file [String]
    # @param config [Hash]
    # @return [Hash]
    def load_terraform(file, config)
      tf_parser = Pharos::Terraform::JsonParser.new(File.read(file))
      config['hosts'] ||= []
      config['api'] ||= {}
      config['hosts'] += tf_parser.hosts
      config['api'].merge!(tf_parser.api) if tf_parser.api
      config
    end

    # @param config_hash [Hash] hash presentation of cluster.yml
    # @return [Pharos::Config]
    def build_config(config_hash)
      schema_class = Pharos::ConfigSchema.build
      schema = schema_class.call(config_hash)
      unless schema.success?
        show_config_errors(schema.messages)
        exit 11
      end

      config = Pharos::Config.new(schema)

      # inject api_endpoint to each host object
      config.hosts.each { |h| h.api_endpoint = config.api&.endpoint }

      signal_usage_error 'No master hosts defined' if config.master_hosts.empty?

      config
    end

    # @param config [Pharos::Config]
    # @param config_content [String]
    def configure(config, config_content:)
      manager = ClusterManager.new(config, config_content: config_content, pastel: pastel)
      start_time = Time.now

      puts pastel.green("==> Sharpening tools ...")
      manager.load
      manager.validate

      puts pastel.green("==> Starting to craft cluster ...")
      manager.apply_phases

      puts pastel.green("==> Configuring addons ...")
      manager.apply_addons

      craft_time = Time.now - start_time
      puts pastel.green("==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})")
      puts "    You can connect to the cluster with kubectl using:"
      puts "    export KUBECONFIG=~/.pharos/#{config.master_host.api_address}"

      manager.disconnect
    end

    # @param secs [Integer]
    # @return [String]
    def humanize_duration(secs)
      [[60, :second], [60, :minute], [24, :hour], [1000, :day]].map{ |count, name|
        next unless secs.positive?
        secs, n = secs.divmod(count).map(&:to_i)
        next if n.zero?
        "#{n} #{name}#{'s' unless n == 1}"
      }.compact.reverse.join(' ')
    end

    def show_config_errors(errors)
      warn "==> Invalid configuration file:"
      warn YAML.dump(errors)
    end
  end
end
