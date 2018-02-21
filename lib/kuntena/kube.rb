require 'kubeclient'

module Kuntena::Kube

  class Client < ::Kubeclient::Client
    def entities
      if @entities.empty?
        discover
      end
      @entities
    end
  end

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
      @kube_client[version] = Kuntena::Kube::Client.new(
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

  # @param host [String]
  # @param resource [Kubeclient::Resource]
  # @return [Kubeclient::Resource]
  def self.apply_resource(host, resource)
    resource_client = self.client(host, resource.apiVersion)
    begin
      definition = resource_client.entities[underscore_entity(resource.kind.to_s)]
      resource_client.get_entity(definition.resource_name, resource.metadata.name, resource.metadata.namespace)
      resource_client.update_entity(definition.resource_name, resource)
    rescue Kubeclient::ResourceNotFoundError
      resource_client.create_entity(resource.kind, definition.resource_name, resource)
    end
  end

  # @param kind [String]
  # @return [String]
  def self.underscore_entity(kind)
    Kubeclient::ClientMixin.underscore_entity(kind.to_s)
  end
end