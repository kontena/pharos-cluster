# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      # @param endpoint [String]
      def initialize(endpoint)
        @endpoint = endpoint
        @clients = {}
      end

      # @return [String]
      def to_s
        @endpoint
      end

      # @return [Boolean]
      def configured?
        Pharos::Kube.config_exists?(@endpoint)
      end

      # @return [Kubeclient::Config]
      def config
        Pharos::Kube.config(@endpoint)
      end

      # @param host [String]
      # @return [Kubeclient::Client]
      def client(version = 'v1')
        @clients[version] ||= Pharos::Kube::Client.from_config(config, version)
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
      # @return [Pharos::Kube::Stack]
      def stack(name, resource_path)
        Stack.new(self, name, resource_path)
      end

      # Discover preferred api group/version strings for this session
      # @return [Array<String>] group/version or version
      def api_versions
        api_versions = []

        client('').apis.groups.each do |api_group|
          api_versions << api_group.preferredVersion.groupVersion
        end

        api_versions << 'v1'

        api_versions
      end
    end
  end
end
