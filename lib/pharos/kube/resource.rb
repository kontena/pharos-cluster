# frozen_string_literal: true
require 'kubeclient'
require 'pathname'

module Pharos
  module Kube
    class Resource
      def initialize(session, resource, vars = {})
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
        @client = session.resource_client(@api_version)
        freeze
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

      # @return [Kubeclient::Resource,FalseClass]
      def delete
        if metadata.selfLink
          api_group = metadata.selfLink.split("/")[1]
          path = metadata.selfLink.gsub("/#{api_group}/#{@api_version}", '')
          @client.rest_client[path].delete
        else
          definition = entity_definition
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

      def metadata
        @resource.metadata
      end

      def kind
        @resource.kind.to_s
      end

      private

      # @param kind [String]
      # @return [String]
      def underscored_entity
        Kubeclient::ClientMixin.underscore_entity(kind)
      end

      def entity_definition
        @client.entities[underscored_entity]
      end
    end
  end
end
