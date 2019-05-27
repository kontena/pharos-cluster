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
        # @param context [Hash] extra keys to initialize cluster context with
        # @return [Pharos::ClusterManager]
        def cluster_manager(context = {})
          @cluster_manager ||= ClusterManager.new(load_config).tap do |manager|
            puts "==> Sharpening tools ...".green
            manager.context.merge!(context)
            manager.load
            manager.validate
          end
        end

        def cluster_context
          cluster_manager.context
        end

        # @return [K8s::Client]
        def kube_client
          cluster_manager.context['kube_client'] || signal_error('no usable master for k8s api client')
        end

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
        def load_config(master_only: false)
          return @config if @config

          puts("==> Reading instructions ...".green) if $stdout.tty?

          config_hash = config_yaml.load(ENV.to_h)

          load_external_config(config_hash)

          config = Pharos::Config.load(config_hash)

          signal_usage_error 'No master hosts defined' if config.master_hosts.empty?

          config.hosts.keep_if(&:master?) if master_only

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
