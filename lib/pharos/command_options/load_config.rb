# frozen_string_literal: true

module Pharos
  module CommandOptions
    module LoadConfig
      using Pharos::CoreExt::Colorize

      def self.included(base)
        base.prepend(InstanceMethods)
        base.option ['-c', '--config'], 'PATH', 'path to config file (default: cluster.yml)', attribute_name: :config_yaml do |config_file|
          begin
            Pharos::YamlFile.new(File.realpath(config_file))
          rescue Errno::ENOENT
            signal_usage_error 'File does not exist: %<path>s' % { path: config_file }
          end
        end

        base.option '--tf-json', 'PATH', 'path to terraform output json' do |config_path|
          begin
            File.realpath(config_path)
          rescue Errno::ENOENT
            signal_usage_error 'File does not exist: %<path>s' % { path: config_path }
          end
        end
      end

      module InstanceMethods
        private

        # @return [Pharos::YamlFile]
        def default_config_yaml
          if !tty? && !stdin_eof?
            Pharos::YamlFile.new($stdin, force_erb: true, override_filename: '<stdin>')
          else
            cluster_config = Dir.glob('cluster.{yml,yml.erb}').first
            signal_usage_error 'File does not exist: cluster.yml' if cluster_config.nil?
            Pharos::YamlFile.new(cluster_config)
          end
        end

        # @return [Pharos::Config]
        def load_config
          return @config if @config
          puts("==> Reading instructions ...".green) if $stdout.tty?

          config_hash = config_yaml.load(ENV.to_h)

          load_terraform(tf_json, config_hash) if tf_json

          config = Pharos::Config.load(config_hash)

          signal_usage_error 'No master hosts defined' if config.master_hosts.empty?

          @config = config
        end

        # @param file [String]
        # @param config [Hash]
        # @return [Hash]
        def load_terraform(file, config)
          puts("==> Importing configuration from Terraform ...".green) if $stdout.tty?

          tf_parser = Pharos::Terraform::JsonParser.new(File.read(file))
          config['hosts'] ||= []
          config['api'] ||= {}
          config['addons'] ||= {}
          config['hosts'] += tf_parser.hosts
          config['api'].merge!(tf_parser.api) if tf_parser.api
          config['addons'].each do |name, conf|
            if addon_config = tf_parser.addons[name]
              conf.merge!(addon_config)
            end
          end
          config
        end
      end
    end
  end
end
