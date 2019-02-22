# frozen_string_literal: true

module Pharos
  module CommandOptions
    module LoadConfig
      using Pharos::CoreExt::Colorize

      def self.included(base)
        base.prepend(InstanceMethods)
        base.option ['-c', '--config'], 'PATH', 'path to config file (default: cluster.yml)', attribute_name: :config_yaml do |config_file|
          @config_options ||= []
          @config_options.concat(['-c', config_file])
          Pharos::YamlFile.new(File.realpath(config_file))
        rescue Errno::ENOENT
          signal_usage_error 'File does not exist: %<path>s' % { path: config_file }
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

          load_external_config(config_hash)

          config = Pharos::Config.load(config_hash)

          signal_usage_error 'No master hosts defined' if config.master_hosts.empty?

          @config = config
        end

        # Config extension point mainly for terraform
        #
        # @param config_hash [Hash]
        def load_external_config(config_hash); end
      end
    end
  end
end
