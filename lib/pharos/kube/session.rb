# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      # @param host [String,Phaross::Configuration::Host]
      def initialize(host)
        @host = host.respond_to?(:api_address) ? host.api_address : host
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
      # @param resource_path [String]
      # @param vars [Hash]
      # @return [Pharos::Kube::Stack]
      def stack(name, resource_path, vars = {})
        Stack.new(self, name, resource_path, vars)
      end

      # Discover preferred api group/version strings for this session
      # @return [Array<String>] group/version or version
      def api_versions
        api_versions = []

        resource_client('').apis.groups.each do |api_group|
          api_versions << api_group.preferredVersion.groupVersion
        end

        api_versions << 'v1'

        api_versions
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
