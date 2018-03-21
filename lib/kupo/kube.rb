# frozen_string_literal: true

require 'kubeclient'
require 'deep_merge'

module Kupo
  module Kube
    class Client < ::Kubeclient::Client
      def entities
        if @entities.empty?
          discover
        end
        @entities
      end

      def update_entity_approval(resource_name, entity_config)
        name      = entity_config[:metadata][:name]
        ns_prefix = build_namespace_prefix(entity_config[:metadata][:namespace])
        response = handle_exception do
          rest_client[ns_prefix + resource_name + "/#{name}/approval"]
            .put(entity_config.to_h.to_json, { 'Content-Type' => 'application/json' }.merge(@headers))
        end
        format_response(@as, response.body)
      end

      def entity_for_resource(resource)
        name = Kubeclient::ClientMixin.underscore_entity(resource.kind.to_s)
        definition = entities[name]

        fail "Unknown entity for resource #{resource.kind} => #{name}" unless definition

        definition
      end

      def apis(options = {})
        response = rest_client.get(@headers)
        format_response(options[:as] || @as, response.body)
      end

      # @param resource [Kubeclient::Resource]
      # @return [Kubeclient::Resource]
      def update_resource(resource)
        definition = entity_for_resource(resource)

        old_resource = get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
        resource.metadata.resourceVersion = old_resource.metadata.resourceVersion
        merged_resource = Kubeclient::Resource.new(old_resource.to_h.deep_merge!(resource.to_h, overwrite_arrays: true))
        update_entity(definition.resource_name, merged_resource)
      end

      # @param resource [Kubeclient::Resource]
      # @return [Kubeclient::Resource]
      def update_resource_approval(resource)
        definition = entity_for_resource(resource)

        update_entity_approval(definition.resource_name, resource)
      end

      # @param resource [Kubeclient::Resource]
      # @return [Kubeclient::Resource]
      def create_resource(resource)
        definition = entity_for_resource(resource)

        create_entity(resource.kind, definition.resource_name, resource)
      end

      # @param resource [Kubeclient::Resource]
      # @return [Kubeclient::Resource]
      def get_resource(resource)
        definition = entity_for_resource(resource)

        get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
      end
    end

    RESOURCE_LABEL = 'kupo.kontena.io/stack'
    RESOURCE_ANNOTATION = 'kupo.kontena.io/stack-checksum'

    # @param host [String]
    # @return [Kubeclient::Client]
    def self.client(host, version = 'v1')
      @kube_client ||= {}
      unless @kube_client[version]
        config = Kubeclient::Config.read(File.join(Dir.home, ".kupo/#{host}"))
        path_prefix = version == 'v1' ? 'api' : 'apis'
        api_version, api_group = version.split('/').reverse
        @kube_client[version] = Kupo::Kube::Client.new(
          (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
          api_version,
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        )
      end
      @kube_client[version]
    end

    # @param host [String]
    # @return [Boolean]
    def self.config_exists?(host)
      File.exist?(File.join(Dir.home, ".kupo/#{host}"))
    end

    # @example
    #   resource_path('host-nodes', '*.yml')
    #   => "<KUPO_DIR>/resources/host-nodes/*.yml"
    # @param path_component [String, ..] extra path components to join to the result
    # @return [String]
    def self.resource_path(*joinables)
      File.join(__dir__, 'resources', *joinables)
    end

    # Returns a list of .yml and .yml.erb files in the stack's resource directory
    # @param stack [String]
    # @return [Array<String>]
    def self.resource_files(stack)
      Dir.glob(resource_path(stack, '*.{yml,yml.erb}'))
    end

    # @param host [Kupo::Configuration::Host]
    # @param stack [String]
    # @param vars [Hash]
    # @return [Array<Kubeclient::Resource>]
    def self.apply_stack(host, stack, vars = {})
      checksum = SecureRandom.hex(16)
      resources = []
      resource_files(stack).each do |file|
        resource = parse_resource_file("#{stack}/#{File.basename(file)}", vars)
        resource.metadata.labels ||= {}
        resource.metadata.annotations ||= {}
        resource.metadata.labels[RESOURCE_LABEL] = stack
        resource.metadata.annotations[RESOURCE_ANNOTATION] = checksum
        apply_resource(host, resource)
        resources << resource
      end
      prune_stack(host, stack, checksum)

      resources
    end

    # @param host [Kupo::Configuration::Host]
    # @param stack [String]
    # @param checksum [String]
    # @return [Array<Kubeclient::Resource>]
    def self.prune_stack(host, stack, checksum)
      pruned = []
      client(host, '').apis.groups.each do |api_group|
        group_client = client(host, api_group.preferredVersion.groupVersion)
        group_client.entities.each do |type, meta|
          next if type.end_with?('_review')
          objects = group_client.get_entities(type, meta.resource_name, label_selector: "#{RESOURCE_LABEL}=#{stack}")
          objects.select { |obj|
            obj.metadata.annotations.nil? || obj.metadata.annotations[RESOURCE_ANNOTATION] != checksum
          }.each { |obj|
            obj.apiVersion = api_group.preferredVersion.groupVersion
            delete_resource(host, obj)
            pruned << obj
          }
        end
      end

      pruned
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def self.apply_resource(host, resource)
      resource_client = client(host, resource.apiVersion)

      begin
        resource_client.update_resource(resource)
      rescue Kubeclient::ResourceNotFoundError
        resource_client.create_resource(resource)
      end
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def self.create_resource(host, resource)
      resource_client = client(host, resource.apiVersion)
      resource_client.create_resource(resource)
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def self.update_resource(host, resource)
      resource_client = client(host, resource.apiVersion)
      resource_client.update_resource(resource)
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def self.get_resource(host, resource)
      resource_client = client(host, resource.apiVersion)
      resource_client.get_resource(resource)
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def self.delete_resource(host, resource)
      resource_client = client(host, resource.apiVersion)
      begin
        if resource.metadata.selfLink
          api_group = resource.metadata.selfLink.split("/")[1]
          resource_path = resource.metadata.selfLink.gsub("/#{api_group}/#{resource.apiVersion}", '')
          resource_client.rest_client[resource_path].delete
        else
          definition = resource_client.entities[underscore_entity(resource.kind.to_s)]
          resource_client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
          resource_client.delete_entity(
            definition.resource_name, resource.metadata.name, resource.metadata.namespace,
            kind: 'DeleteOptions',
            apiVersion: 'v1',
            propagationPolicy: 'Foreground'
          )
        end
      rescue Kubeclient::ResourceNotFoundError
        false
      end
    end

    # @param path [String]
    # @return [Kubeclient::Resource]
    def self.parse_resource_file(path, vars = {})
      Kubeclient::Resource.new(
        Kupo::Erb.new(File.realpath(resource_path(path))).load_yaml(vars)
      )
    end

    # @param kind [String]
    # @return [String]
    def self.underscore_entity(kind)
      Kubeclient::ClientMixin.underscore_entity(kind.to_s)
    end
  end
end
