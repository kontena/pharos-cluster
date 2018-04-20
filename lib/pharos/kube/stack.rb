# frozen_string_literal: true

module Pharos
  module Kube
    class Stack
      RESOURCE_LABEL = 'pharos.kontena.io/stack'
      RESOURCE_ANNOTATION = 'pharos.kontena.io/stack-checksum'
      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources'))).freeze

      # @param session [Pharos::Kube::Session]
      # @param name [String] stack name
      def initialize(session, name)
        @session = session
        @name = name
        @resource_path = RESOURCE_PATH.join(name).freeze
      end

      # A list of .yml and yml.erb files in the stacks resource directory
      # @return [Array<Pathname>]
      def resource_files
        Pathname.glob(@resource_path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
      end

      # A list of resources
      # @return [Array<Pharos::Kube::Resource>]
      def load_resources(vars)
        resource_files.map do |resource_file|
          @session.resource(Pharos::YamlFile.new(resource_file).load(vars))
        end
      end

      # Applies the stack onto the kube cluster
      # @return [Array<Kubeclient::Resource>]
      def apply(**vars)
        with_pruning do |checksum|
          load_resources(vars).map do |resource|
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
      def prune(checksum = nil)
        pruned = []

        @session.api_groups.each do |api_group|
          group_client = @session.client(api_group.preferredVersion.groupVersion)

          entities = group_client.entities.reject { |type, _| type.end_with?('_review') }

          objects = entities.flat_map do |type, meta|
            group_client.get_entities(type, meta.resource_name, label_selector: "#{RESOURCE_LABEL}=#{@name}")
          end

          if checksum
            prunables = objects.select do |obj|
              annotations = obj.metadata.annotations
              annotations.nil? || annotations[RESOURCE_ANNOTATION] != checksum
            end
          else
            prunables = objects
          end

          prunables.each do |obj|
            obj.apiVersion = api_group.preferredVersion.groupVersion
            pruned << obj if @session.resource(obj).delete
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
