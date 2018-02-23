require 'kubeclient'
require 'deep_merge'
module Kontadm::Kube

  class Client < ::Kubeclient::Client
    def entities
      if @entities.empty?
        discover
      end
      @entities
    end

    def apis(options= {})
      response = rest_client.get(@headers)
      format_response(options[:as] || @as, response.body)
    end
  end

  RESOURCE_LABEL = 'kontadm.kontena.io/stack'.freeze
  RESOURCE_ANNOTATION = 'kontadm.kontena.io/stack-checksum'.freeze

  # @param host [String]
  # @return [Kubeclient::Client]
  def self.client(host, version = 'v1')
    @kube_client ||= {}
    unless @kube_client[version]
      config = Kubeclient::Config.read(File.join(Dir.home, ".kube/#{host}"))
      if version == 'v1'
        path_prefix = 'api'
      else
        path_prefix = 'apis'
      end
      api_version, api_group = version.split('/').reverse
      @kube_client[version] = Kontadm::Kube::Client.new(
        (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
        api_version,
        {
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        }
      )
    end
    @kube_client[version]
  end

  # @param host [Kontadm::Configuration::Host]
  # @param stack [String]
  # @param vars [Hash]
  # @return [Array<Kubeclient::Resource>]
  def self.apply_stack(host, stack, vars = {})
    checksum = SecureRandom.hex(16)
    resources = []
    Dir.glob(File.join(__dir__, 'resources', stack, '*.yml')).each do |file|
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

  # @param host [Kontadm::Configuration::Host]
  # @param stack [String]
  # @param checksum [String]
  # @return [Array<Kubeclient::Resource>]
  def self.prune_stack(host, stack, checksum)
    pruned = []
    client(host, '').apis.groups.each do |api_group|
      group_client = client(host, api_group.preferredVersion.groupVersion)
      group_client.entities.each do |type, meta|
        unless type.end_with?('_review')
          objects = group_client.get_entities(type, meta.resource_name, {label_selector: "#{RESOURCE_LABEL}=#{stack}"})
          objects.select { |obj|
            obj.metadata.annotations.nil? || obj.metadata.annotations[RESOURCE_ANNOTATION] != checksum
          }.each { |obj|
            delete_resource(obj)
            pruned << obj
          }
        end
      end
    end

    pruned
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.apply_resource(host, resource)
    resource_client = self.client(host, resource.apiVersion)
    begin
      definition = resource_client.entities[underscore_entity(resource.kind.to_s)]
      old_resource = resource_client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
      resource.metadata.resourceVersion = old_resource.metadata.resourceVersion
      merged_resource = Kubeclient::Resource.new(old_resource.to_h.deep_merge!(resource.to_h, {overwrite_arrays: true}))
      resource_client.update_entity(definition.resource_name, merged_resource)
    rescue Kubeclient::ResourceNotFoundError
      resource_client.create_entity(resource.kind, definition.resource_name, resource)
    end
  end

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.delete_resource(host, resource)
    resource_client = self.client(host, resource.apiVersion)
    begin
      definition = resource_client.entities[underscore_entity(resource.kind.to_s)]
      resource_client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
      resource_client.delete_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
    rescue Kubeclient::ResourceNotFoundError
      false
    end
  end

  # @param path [String]
  # @return [Kubeclient::Resource]
  def self.parse_resource_file(path, vars = {})
    yaml = File.read(File.realpath(File.join(__dir__, 'resources', path)))
    parsed_yaml = Kontadm::Erb.new(yaml).render(vars)

    Kubeclient::Resource.new(YAML.load(parsed_yaml))
  end

  # @param kind [String]
  # @return [String]
  def self.underscore_entity(kind)
    Kubeclient::ClientMixin.underscore_entity(kind.to_s)
  end
end