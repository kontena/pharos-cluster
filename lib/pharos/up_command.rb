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

    option ['-y', '--yes'], :flag, 'Answer automatically yes to prompts'

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
      puts pastel.bright_green("==> KONTENA PHAROS v#{Pharos::VERSION} (Kubernetes v#{Pharos::KUBE_VERSION})")
      puts pastel.green("==> Reading instructions ...")
      config_hash = load_config
      if tf_json
        puts pastel.green("==> Importing configuration from Terraform ...")
        load_terraform(tf_json, config_hash)
      end

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        config = build_config(config_hash)
        configure(config)
      end
    rescue Pharos::ConfigError => exc
      show_config_errors(exc)
      exit 11
    rescue StandardError => ex
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{ex.class.name} : #{ex.message}"
      exit 1
    end

    # @return [Hash] hash presentation of cluster.yml
    def load_config
      config_yaml.load(ENV.to_h)
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
      config = Pharos::Config.load(config_hash)

      signal_usage_error 'No master hosts defined' if config.master_hosts.empty?

      config
    end

    # @param config [Pharos::Config]
    # @param config_content [String]
    def configure(config)
      manager = ClusterManager.new(config, pastel: pastel)
      start_time = Time.now

      puts pastel.green("==> Sharpening tools ...")
      manager.load
      manager.validate

      show_component_versions(config)
      prompt_continue(config)

      puts pastel.green("==> Starting to craft cluster ...")
      manager.apply_phases

      puts pastel.green("==> Configuring addons ...")
      manager.apply_addons

      manager.save_config

      craft_time = Time.now - start_time
      puts pastel.green("==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})")
      puts "    You can connect to the cluster with kubectl using:"
      puts "    export KUBECONFIG=~/.pharos/#{manager.sorted_master_hosts.first.api_address}"

      manager.disconnect
    end

    # @param config [Pharos::Config]
    def show_component_versions(config)
      puts pastel.green("==> Using following software versions:")
      Pharos::Phases.components_for_config(config).sort_by(&:name).each do |c|
        puts "    #{c.name}: #{c.version}"
      end
    end

    # @param config [Pharos::Config]
    def prompt_continue(config)
      lexer = Rouge::Lexers::YAML.new
      puts pastel.green("==> Configuration is generated and shown below:")
      if color?
        puts rouge.format(lexer.lex(config.to_yaml))
        puts ""
      else
        puts yaml
      end
      if $stdin.tty? && !yes?
        exit 1 unless prompt.yes?('Continue?')
      end
    rescue TTY::Reader::InputInterrupt
      exit 1
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

    # @param error [Pharos::ConfigError]
    def show_config_errors(error)
      warn "==> #{error}"
    end
  end
end
