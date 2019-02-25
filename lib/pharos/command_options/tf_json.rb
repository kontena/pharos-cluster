# frozen_string_literal: true

module Pharos
  module CommandOptions
    module TfJson
      using Pharos::CoreExt::Colorize

      def self.included(base)
        base.prepend(InstanceMethods)

        base.option '--tf-json', 'PATH', 'path to terraform output json' do |config_path|
          @config_options ||= []
          @config_options.concat(['--tf-json', config_path])
          File.realpath(config_path)
        rescue Errno::ENOENT
          signal_usage_error 'File does not exist: %<path>s' % { path: config_path }
        end
      end

      module InstanceMethods
        private

        # @param config_hash [Hash]
        def load_external_config(config_hash)
          load_terraform(tf_json, config_hash) if tf_json
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
          config['hosts'].concat(tf_parser.hosts)
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
