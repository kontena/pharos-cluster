# frozen_string_literal: true

module Pharos
  module Kube
    class Stack
      RESOURCE_LABEL = 'pharos.kontena.io/stack'
      RESOURCE_ANNOTATION = 'pharos.kontena.io/stack-checksum'
      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources'))).freeze

      def initialize(session, name, vars = {})
        @session = session
        @name = name
        @resource_path = RESOURCE_PATH.join(name).freeze
        @vars = vars
        freeze
      end

      def resource_files
        Pathname.glob(@resource_path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
      end

      def resources
        resource_files.map do |resource_file|
          @session.resource(resource_file, @vars)
        end
      end

      # @return [Array<Kubeclient::Resource>]
      def apply
        with_pruning do |checksum|
          resources.map do |resource|
            resource.metadata.labels ||= {}
            resource.metadata.annotations ||= {}
            resource.metadata.labels[RESOURCE_LABEL] = @name
            resource.metadata.annotations[RESOURCE_ANNOTATION] = checksum
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
          group_client = @session.resource_client(api_group.preferredVersion.groupVersion)

          entities = group_client.entities.reject { |type, _| type.end_with?('_review') }

          objects = entities.flat_map do |type, meta|
            group_client.get_entities(type, meta.resource_name, label_selector: "#{RESOURCE_LABEL}=#{@name}")
          end

          prunables = objects.select do |obj|
            annotations = obj.metadata.annotations
            annotations.nil? || annotations[RESOURCE_ANNOTATION] != checksum
          end

          prunables.each do |obj|
            pruned << obj if @session.resource(obj).delete
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
