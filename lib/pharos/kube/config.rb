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

      def yaml_content
        Pharos::YamlFile.new(StringIO.new(@content)).load unless @content.nil?
      end
      private :yaml_content

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

      def self.from_remote(content, cluster_config, host)
        instance = new(content)

        unless instance.config['clusters'].size == 1
          raise InvalidConfigError, "Remote configuration cluster count expected to be one"
        end

        cluster = instance.config['clusters']&.first

        cluster_name = cluster_config&.name || cluster['name']

        # Overwrite server address and cluster name
        cluster['cluster']['server'] = "https://#{host.api_address}:6443"
        cluster['name'] = cluster_name

        unless instance.config['contexts'].size == 1
          raise InvalidConfigError, "Remote configuration context count expected to be one"
        end

        if cluster_config&.kube_config&.user
          # Rename user as configured in cluster yaml
          user_name = cluster_config&.kube_config&.user
          instance.config['users'].first['name'] = user_name
        else
          user_name = instance.config['users'].first['name']
        end

        # Rename cluster and user in context
        context = instance.config['contexts'].first
        context['context']['cluster'] = cluster_name
        context['context']['user'] = user_name

        config_context = cluster_config&.kube_config&.context

        if config_context
          # Rename context & current context to one specified in config
          context['name'] = config_context
          instance.config['current-context'] = config_context
        else
          # Rename context & current context to match cluster.yml cluster name and user name
          context_name = "#{user_name}@#{cluster_name}"
          instance.config['current-context'] = context_name
          context['name'] = context_name
        end

        instance
      end
    end
  end
end
