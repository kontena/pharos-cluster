# frozen_string_literal: true

require 'pharos/yaml_file'

module Pharos
  module Kube
    # Loads and manipulates kubeconfig files
    class Config
      InvalidConfigError = Class.new(Pharos::Error)

      # @param content [String] configuration content
      def initialize(content = nil)
        @content = content
      end

      # Accessor to the configuration hash. Will use the YAML content for initialization if available.
      # @return [Hash]
      def config
        @config ||= yaml_content || {
          'apiVersion' => 'v1',
          'clusters' => [],
          'contexts' => [],
          'current-context' => nil,
          'kind' => 'Config',
          'preferences' => {},
          'users' => []
        }
      end
      alias to_h config

      # Convert to YAML
      # @return [String]
      def dump
        YAML.dump(config)
      end
      alias to_s dump

      # Performs a merge of another kubeconfig into the current instance
      # @param other [Pharos::Kube::Config]
      def merge!(other)
        other.config.each do |key, value|
          case key
          when 'clusters', 'contexts', 'users'
            value.each do |other_value|
              own_value = config[key].find { |c| c['name'] == other_value['name'] }
              config[key].delete(own_value) if own_value
              config[key] << other_value
            end
          when 'current-context', 'preferences'
            config[key] = value
          else
            config[key] ||= value
          end
        end

        self
      end
      alias << merge!

      # Create a duplicate
      # @return [Pharos::Kube::Config]
      def dup
        self.class.new(@content)
      end
      alias clone dup

      # Performs a merge and returns a new instance
      # @param other_config [Pharos::Kube::Config]
      # @return [Pharos::Kube::Config]
      def merge(other)
        dup << other
      end
      alias + merge

      def rename_cluster(new_name)
        unless config['clusters'].size == 1
          raise InvalidConfigError, "Configuration cluster count expected to be one"
        end

        cluster = config['clusters']&.first
        cluster['name'] = new_name

        return self unless config['contexts'].size == 1 && config['users'].size == 1

        # Rename cluster in context
        context = config['contexts'].first
        context['context']['cluster'] = new_name

        self
      end

      def rename_context(new_name)
        unless config['clusters'].size == 1
          raise InvalidConfigError, "Configuration cluster count expected to be one"
        end

        unless config['contexts'].size == 1
          raise InvalidConfigError, "Configuration context count expected to be one"
        end

        context = config['contexts'].first

        context['name'] = new_name
        config['current-context'] = new_name

        self
      end

      def update_server_address(new_address)
        unless config['clusters'].size == 1
          raise InvalidConfigError, "Configuration cluster count expected to be one"
        end

        config['clusters'].first['cluster']['server'].gsub!(%r{(server: https://)(.+)(:6443)}, "\\1#{new_address}\\3")
      end

      private

      def yaml_content
        Pharos::YamlFile.new(StringIO.new(@content)).load unless @content.nil?
      end
    end
  end
end
