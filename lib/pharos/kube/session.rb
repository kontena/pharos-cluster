# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      def initialize(host)
        @host = host.respond_to?(:address) ? host.address : host
        @resource_clients = {}
        freeze
      end

      def resource(resource, vars = {})
        Resource.new(self, resource, vars)
      end

      def stack(name, vars = {})
        Stack.new(self, name, vars)
      end

      def api_groups
        resource_client('').apis.groups
      end

      def resource_client(version = 'v1')
        client = @resource_clients[version] ||= Pharos::Kube.client(@host, version)
        block_given? ? yield(client) : client
      end
    end
  end
end
