# frozen_string_literal: true
require 'kubeclient'
require 'pathname'

module Pharos
  module Kube
    class Resource
      def initialize(session, resource)
        @session = session
        @resource =
          case resource
          when Kubeclient::Resource
            resource
          when Hash
            Kubeclient::Resource.new(resource)
          else
            raise TypeError, "Expected an instance of KubeClient::Resource or Hash"
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
        Resource.new(@session, @client.get_resource(@resource))
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

      def [](key)
        @resource.send(key)
      end

      def []=(key, value)
        @resource.send("#{key}=", value)
      end

      def fetch(key, default = nil, &block)
        val = send(:[], key)
        if val.nil?
          if default
            default
          elsif block_given?
            yield
          else
            raise NameError, "unknown attribute #{key} for resource"
          end
        else
          val
        end
      end

      def attributes
        @resource
      end

      def metadata
        fetch(:metadata) { @resource.metadata = {} }
      end

      def kind
        fetch(:kind)
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
