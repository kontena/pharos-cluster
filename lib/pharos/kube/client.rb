# frozen_string_literal: true

require 'kubeclient'
require 'deep_merge'

module Pharos
  module Kube
    class Client < ::Kubeclient::Client
      # @param config [Kubeclient::Config]
      # @param version [String] v1, apps/v1, ...
      def self.from_config(config, version)
        path_prefix = version == 'v1' ? 'api' : 'apis'
        api_group, api_version = version.split('/')

        new(
          (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
          api_version,
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        )
      end

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

      # @param resource [Kubeclient::Resource]
      def delete_resource(resource, propagation_policy: 'Foreground')
        definition = entity_for_resource(resource)

        delete_entity(
          definition.resource_name,
          resource.metadata.name,
          resource.metadata.namespace,
          delete_options: {
            apiVersion: 'v1',
            kind: 'DeleteOptions',
            propagationPolicy: propagation_policy
          }
        )
      end
    end
  end
end
