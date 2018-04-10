# frozen_string_literal: true

require 'kubeclient'
require 'deep_merge'

module Pharos
  class Kube
    autoload :CertManager, 'pharos/kube/cert_manager'
    autoload :Client, 'pharos/kube/client'

    RESOURCE_LABEL = 'pharos.kontena.io/stack'
    RESOURCE_ANNOTATION = 'pharos.kontena.io/stack-checksum'

    # @param host [String]
    # @return [Kubeclient::Client]
    def self.client(host, version = 'v1')
      @kube_client ||= {}
      unless @kube_client[version]
        config = Kubeclient::Config.read(File.join(Dir.home, ".pharos/#{host}"))
        path_prefix = version == 'v1' ? 'api' : 'apis'
        api_version, api_group = version.split('/').reverse
        @kube_client[version] = Pharos::Kube::Client.new(
          (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
          api_version,
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        )
      end
      @kube_client[version]
    end

    # Returns a list of .yml and .yml.erb pathnames in the stack's resource directory
    # @param stack [String]
    # @return [Array<Pathname>]
    def self.resource_files(stack)
      Pathname.glob(resource_path(stack, '*.{yml,yml.erb}')).sort_by(&:to_s)
    end

    # @example
    #   resource_path('host-nodes', '*.yml')
    #   => "<PHAROS_DIR>/resources/host-nodes/*.yml"
    # @param path_component [String, ..] extra path components to join to the result
    # @return [String]
    def self.resource_path(*joinables)
      File.join(__dir__, 'resources', *joinables)
    end

    # @param path [String]
    # @return [Kubeclient::Resource]
    def self.parse_resource_file(path, vars = {})
      Kubeclient::Resource.new(Pharos::YamlFile.new(path).load(vars))
    end

    def self.method_missing(meth, *args)
      return super unless respond_to_missing?(meth)
      Pharos::Kube.new(args.shift).send(meth, *args)
    end

    def self.respond_to_missing?(meth, include_private = false)
      Pharos::Kube.public_method_defined?(meth) || super
    end

    attr_reader :host

    def initialize(host)
      @host = host.respond_to?(:address) ? host.address : host
    end

    # @return [Boolean]
    def config_exists?
      File.exist?(File.join(Dir.home, ".pharos/#{host}"))
    end

    # @param stack [String]
    # @param vars [Hash]
    # @return [Array<Kubeclient::Resource>]
    def apply_stack(stack, vars = {})
      checksum = SecureRandom.hex(16)
      resources = []
      resource_files(stack).each do |file|
        resource = parse_resource_file(file, vars)
        resource.metadata.labels ||= {}
        resource.metadata.annotations ||= {}
        resource.metadata.labels[RESOURCE_LABEL] = stack
        resource.metadata.annotations[RESOURCE_ANNOTATION] = checksum
        apply_resource(resource)
        resources << resource
      end
      prune_stack(stack, checksum)

      resources
    end

    # @param stack [String]
    # @param checksum [String]
    # @return [Array<Kubeclient::Resource>]
    def prune_stack(stack, checksum)
      pruned = []
      Pharos::Kube.client(host, '').apis.groups.each do |api_group|
        group_client = Pharos::Kube.client(host, api_group.preferredVersion.groupVersion)
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

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def apply_resource(resource)
      resource_client(resource) do |client|
        begin
          client.update_resource(resource)
        rescue Kubeclient::ResourceNotFoundError
          client.create_resource(resource)
        end
      end
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def create_resource(resource)
      resource_client(resource).create_resource(resource)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def update_resource(resource)
      resource_client(resource).update_resource(resource)
    end

    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def get_resource(resource)
      resource_client(resource).get_resource(resource)
    end

    # @param host [String]
    # @param resource [Kubeclient::Resource]
    # @return [Kubeclient::Resource]
    def delete_resource(resource)
      resource_client(resource) do |client|
        begin
          if resource.metadata.selfLink
            api_group = resource.metadata.selfLink.split("/")[1]
            resource_path = resource.metadata.selfLink.gsub("/#{api_group}/#{resource.apiVersion}", '')
            client.rest_client[resource_path].delete
          else
            definition = client.entities[underscore_entity(resource.kind.to_s)]
            client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
            client.delete_entity(
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
    end

    private

    def parse_resource_file(path, vars = {})
      self.class.parse_resource_file(path, vars)
    end

    # @param kind [String]
    # @return [String]
    def underscore_entity(kind)
      Kubeclient::ClientMixin.underscore_entity(kind.to_s)
    end

    def resource_path(*joinables)
      self.class.resource_path(*joinables)
    end

    def resource_files(stack)
      self.class.resource_files(stack)
    end

    def resource_client(resource)
      client = Pharos::Kube.client(host, resource.apiVersion)
      block_given? ? yield(client) : client
    end
  end
end
