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
        freeze
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

        @session.api_groups.each do |api_group|
          client = @session.resource_client(api_group.preferredVersion.groupVersion)
          client.entities.each do |method_name, entity|
            next if method_name.end_with?('_review')

            resources = client.get_entities(entity.entity_type, entity.resource_name, label_selector: "#{RESOURCE_LABEL}=#{@name}")
            resources = resources.select do |obj|
              annotations = obj.metadata.annotations
              annotations.nil? || annotations[RESOURCE_ANNOTATION] != checksum
            end

            resources.each do |resource|
              # the items in a list are missing the apiVersion and kind
              resource.apiVersion = api_group.preferredVersion.groupVersion
              resource.kind = entity.entity_type

              next unless @session.resource(resource).delete

              pruned << resource
            end
          end
        end

        pruned
      end

      private

      def with_pruning
        checksum = SecureRandom.hex(16)
        result = yield checksum
        prune(checksum)
        result
      end
    end
  end
end
