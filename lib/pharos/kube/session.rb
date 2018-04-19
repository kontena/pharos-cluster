# frozen_string_literal: true

require_relative '../kube'

module Pharos
  module Kube
    class Session
      # @param host [Pharos::Configuration::Host]
      def initialize(host)
        @host = host
        @clients = {}
      end

      # @return [String]
      def to_s
        @host.to_s
      end

      # @return [Boolean]
      def configured?
        Pharos::Kube.host_config_exists?(@host)
      end

      # @param host [String]
      # @return [Kubeclient::Client]
      def client(version = 'v1')
        @clients ||= {}
        @clients[version] ||= Pharos::Kube::Client.for_host(@host, version)
      end

      # Returns a new resource associated with this session
      # @param resource [Kubeclient::Resource,Hash]
      # @return [Pharos::Kube::Resource]
      def resource(resource)
        Resource.new(self, resource)
      end

      # Returns a new stack associated with this session
      # @param name [String]
      # @return [Pharos::Kube::Stack]
      def stack(name)
        Stack.new(self, name)
      end

      # List of api groups available for the session
      def api_groups
        client('').apis.groups
      end
    end
  end
end
