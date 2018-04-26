# frozen_string_literal: true

module Pharos
  module Kube
    class Stack
      RESOURCE_LABEL = 'pharos.kontena.io/stack'
      RESOURCE_ANNOTATION = 'pharos.kontena.io/stack-checksum'
      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources'))).freeze

      # @param session [Pharos::Kube::Session]
      # @param name [String] stack name
      # @param vars [Hash] variables for ERB evaluation
      def initialize(session, name, vars = {})
        @session = session
        @name = name
        @resource_path = RESOURCE_PATH.join(name).freeze
        @vars = vars
      end

      # A list of .yml and yml.erb files in the stacks resource directory
      # @return [Array<Pathname>]
      def resource_files
        Pathname.glob(@resource_path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
      end

      # A list of resources
      # @return [Array<Pharos::Kube::Resource>]
      def resources
        resource_files.map do |resource_file|
          @session.resource(Pharos::YamlFile.new(resource_file).load(@vars))
        end
      end

      # Applies the stack onto the kube cluster
      # @return [Array<Kubeclient::Resource>]
      def apply
        with_pruning do |checksum|
          resources.map do |resource|
            metadata = resource.metadata
            metadata.labels ||= {}
            metadata.annotations ||= {}
            metadata.labels[RESOURCE_LABEL] = @name
            metadata.annotations[RESOURCE_ANNOTATION] = checksum
            resource.apply
            resource
          end
        end
      end

      # @param checksum [String]
      # @return [Array<Kubeclient::Resource>]
      def prune(checksum)
        pruned = []

        @session.api_versions.each do |api_version|
          client = @session.resource_client(api_version)
          client.entities.each do |method_name, entity|
            next if method_name.end_with?('_review')
            next if api_version == 'v1' && entity.resource_name == 'bindings' # XXX: the entity definition does not have the list verb... but kubeclient does not expose that
            next if api_version == 'v1' && entity.resource_name == 'componentstatuses' # apiserver ignores the ?labelSelector query

            resources = client.get_entities(entity.entity_type, entity.resource_name, label_selector: "#{RESOURCE_LABEL}=#{@name}")
            resources = resources.select do |obj|
              annotations = obj.metadata.annotations
              annotations.nil? || annotations[RESOURCE_ANNOTATION] != checksum
            end

            resources.each do |resource|
              # the items in a list are missing the apiVersion and kind
              resource.apiVersion = api_version
              resource.kind = entity.entity_type

              next unless @session.resource(resource).delete

              pruned << resource
            end
          end
        end

        pruned
      end

      private

      def random_checksum
        SecureRandom.hex(16)
      end

      def with_pruning
        checksum = random_checksum
        result = yield checksum
        prune(checksum)
        result
      end
    end
  end
end
