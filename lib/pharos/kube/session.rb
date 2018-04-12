# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      # @param host [String,Phaross::Configuration::Host]
      def initialize(host)
        @host = host.respond_to?(:address) ? host.address : host
        freeze
      end

      # Returns a new resource associated with this session
      # @param resource [Kubeclient::Resource,Hash]
      # @return [Pharos::Kube::Resource]
      def resource(resource)
        Resource.new(self, resource)
      end

      # Returns a new stack associated with this session
      # @param name [String]
      # @param vars [Hash]
      # @return [Pharos::Kube::Stack]
      def stack(name, vars = {})
        Stack.new(self, name, vars)
      end

      # List of api groups available for the session
      def api_groups
        resource_client('').apis.groups
      end

      # A Pharos::Kube::Client instance for the session's host and
      # the specified api version.
      # @param version [String]
      # @return [Pharos::Kube::Client]
      # @yield [Pharos::Kube::Client]
      def resource_client(version = 'v1')
        client = Pharos::Kube.client(@host, version)
        block_given? ? yield(client) : client
      end
    end
  end
end
