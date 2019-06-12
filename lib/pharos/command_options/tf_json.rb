# frozen_string_literal: true

module Pharos
  module CommandOptions
    module TfJson
      using Pharos::CoreExt::Colorize
      using K8s::Util::HashDeepMerge

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
            config['addons'].each do |name, conf|
              if addon_config = tf_parser.addons[name]
                conf.merge!(addon_config)
              end
            end
          end

          config['hosts'].each do |host|
            if host[:ssh_key_path]
              unless File.exist?(host[:ssh_key_path])
                expanded = File.expand_path(host[:ssh_key_path])
                host[:ssh_key_path] = File.exist?(expanded) ? expanded : File.join(File.dirname(file), host[:ssh_key_path])
              end
            end

            next unless host.dig(:bastion, :ssh_key_path)

            unless File.exist?(host[:bastion][:ssh_key_path])
              expanded = File.expand_path(host[:bastion][:ssh_key_path])
              host[:ssh_key_path] = File.exist?(expanded) ? expanded : File.join(File.dirname(file), host[:bastion][:ssh_key_path])
            end
          end
        end
      end
    end
  end
end
