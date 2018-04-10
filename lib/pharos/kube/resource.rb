# frozen_string_literal: true
require 'kubeclient'
require 'pathname'

module Pharos
  module Kube
    class Resource
      def initialize(host, resource, vars = {})
        @resource =
          case resource
          when Kubeclient::Resource
            resource
          when Hash
            Kubeclient::Resource.new(resource)
          else
            Kubeclient::Resource.new(Pharos::YamlFile.new(resource).load(vars))
          end
        @api_version = @resource.apiVersion || 'v1'
        @client = Pharos::Kube.client(host, @api_version)
      end

      def metadata
        @resource.metadata
      end

      # @return [Kubeclient::Resource]
      def apply
        update
      rescue Kubeclient::ResourceNotFoundError
        create
      end

      # @return [Kubeclient::Resource]
      def create
        @client.create_resource(@resource)
      end

      # @return [Kubeclient::Resource]
      def update
        @client.update_resource(@resource)
      end

      # @return [Kubeclient::Resource]
      def get
        @client.get_resource(@resource)
      end

      # @return [Kubeclient::Resource]
      def delete
        if resource.metadata.selfLink
          api_group = metadata.selfLink.split("/")[1]
          path = metadata.selfLink.gsub("/#{api_group}/#{@api_version}", '')
          @client.rest_client[path].delete
        else
          definition = @client.entities[underscore_entity(@resource.kind.to_s)]
          @client.get_entity(definition.resource_name, metadata.name, metadata.namespace)
          @client.delete_entity(
            definition.resource_name, metadata.name, metadata.namespace,
            kind: 'DeleteOptions',
            apiVersion: 'v1',
            propagationPolicy: 'Foreground'
          )
        end
      rescue Kubeclient::ResourceNotFoundError
        false
      end

      private

      # @param kind [String]
      # @return [String]
      def underscore_entity(kind)
        Kubeclient::ClientMixin.underscore_entity(kind.to_s)
      end
    end
  end
end
