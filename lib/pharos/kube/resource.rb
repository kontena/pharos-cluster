# frozen_string_literal: true

require 'kubeclient'
require 'pathname'

module Pharos
  module Kube
    # A wrapper around Kubeclient::Resource that works with a Pharos::Kube::Session
    class Resource
      # @param session [Pharos::Kube::Session]
      # @param resource [Kubeclient::Resource,Hash]
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

      # Creates a new resource or updates existing
      # @return [Kubeclient::Resource]
      def apply
        update
      rescue Kubeclient::ResourceNotFoundError
        create
      end

      # Creates a resource
      # @return [Kubeclient::Resource]
      def create
        @client.create_resource(@resource)
      end

      # Updates a resource
      # @return [Kubeclient::Resource]
      def update
        @client.update_resource(@resource)
      end

      # Retrieves a resource from kube and returns a new instance of Resource
      # @return [Pharos::Kube::Resource]
      def get
        Resource.new(@session, @client.get_resource(@resource))
      end

      # Deletes the resource from kube.
      # Returns false if the resource does not exist.
      #
      # @return [Kubeclient::Resource,FalseClass]
      def delete(**options)
        @client.delete_resource(@resource, **options)
      rescue Kubeclient::ResourceNotFoundError
        false
      end

      # Accessor to the original resource
      def attributes
        @resource
      end

      def method_missing(meth, *args)
        attributes.send(meth, *args)
      rescue NameError
        super
      end

      def respond_to_missing?(meth, include_private = false)
        attributes.respond_to?(meth, include_private) || super
      end
    end
  end
end
