# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      def initialize(host)
        @host = host.respond_to?(:address) ? host.address : host
        freeze
      end

      def resource(resource)
        Resource.new(self, resource)
      end

      def stack(name, vars = {})
        Stack.new(self, name, vars)
      end

      def api_groups
        resource_client('').apis.groups
      end

      def resource_client(version = 'v1')
        client = Pharos::Kube.client(@host, version)
        block_given? ? yield(client) : client
      end
    end
  end
end
