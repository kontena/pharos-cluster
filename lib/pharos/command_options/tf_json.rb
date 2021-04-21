# frozen_string_literal: true

module Pharos
  module CommandOptions
    module TfJson
      using Pharos::CoreExt::Colorize
      using Pharos::CoreExt::DeepTransformKeys
      using K8s::Util::HashDeepMerge

      def self.included(base)
        base.prepend(InstanceMethods)

        base.option '--tf-json', 'PATH', 'path to terraform output json' do |config_path|
          @config_options ||= []
          @config_options.concat(['--tf-json', config_path])
          File.expand_path(config_path)
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

          Dir.chdir(File.dirname(file)) do
            json = File.read(file)
            tf_parser = Pharos::Terraform::JsonParser.new(json)
            if tf_parser.valid?
              config.deep_merge!(
                tf_parser.cluster,
                overwrite_arrays: false,
                union_arrays: true
              )
            else
              tf_parser = Pharos::Terraform::LegacyJsonParser.new(json)
              config['hosts'] ||= []
              config['api'] ||= {}
              config['addons'] ||= {}
              config['hosts'].concat(tf_parser.hosts)
              config['api'].merge!(tf_parser.api) if tf_parser.api
              config['name'] ||= tf_parser.cluster_name if tf_parser.cluster_name
              tf_parser.addons.each do |name, conf|
                if config['addons'][name]
                  config['addons'][name].merge!(conf)
                else
                  config['addons'][name] = conf
                end
              end
            end

            config.deep_stringify_keys!

            config['hosts'].each do |host|
              host['ssh_key_path'] = File.expand_path(host['ssh_key_path']) if host['ssh_key_path']

              next unless host.dig('bastion', 'ssh_key_path')

              host['bastion']['ssh_key_path'] = File.expand_path(host['bastion']['ssh_key_path'])
            end
          end
        end
      end
    end
  end
end
