# frozen_string_literal: true

module Pharos
  module Kube
    class Stack
      RESOURCE_LABEL = 'pharos.kontena.io/stack'
      RESOURCE_ANNOTATION = 'pharos.kontena.io/stack-checksum'
      RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, '..', 'resources'))).freeze

      def initialize(host, name, vars = {})
        @host = host
        @name = name
        @resource_path = RESOURCE_PATH.join(name).freeze
        @vars = vars
      end

      def resource_files
        Pathname.glob(@resource_path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
      end

      def resources
        resource_files.map do |resource_file|
          Resource.new(@host, resource_file, @vars)
        end
      end

      # @return [Array<Kubeclient::Resource>]
      def apply
        checksum = SecureRandom.hex(16)
        processed = []
        resources.each do |resource|
          resource.metadata.labels ||= {}
          resource.metadata.annotations ||= {}
          resource.metadata.labels[RESOURCE_LABEL] = @name
          resource.metadata.annotations[RESOURCE_ANNOTATION] = checksum
          resource.apply
          processed << resource
        end
        prune(checksum)

        resources
      end

      # @param checksum [String]
      # @return [Array<Kubeclient::Resource>]
      def prune(checksum)
        pruned = []
        api_groups.each do |api_group|
          client = group_client(api_group)
          client.entities.each do |type, meta|
            next if type.end_with?('_review')
            objects = client.get_entities(type, meta.resource_name, label_selector: "#{RESOURCE_LABEL}=#{@name}")
            objects.map { |obj| Resource.new(@host, obj) }.each do |obj|
              next unless obj.metadata.annotations.nil? || obj.metadata.annotations[RESOURCE_ANNOTATION] != checksum
              obj.apiVersion = api_group.preferredVersion.groupVersion
              obj.delete
              pruned << obj
            end
          end
        end
        pruned
      end

      private

      def api_groups
        Pharos::Kube.client(@host, '').apis.groups
      end

      def group_client(api_group)
        Pharos::Kube.client(@host, api_group.preferredVersion.groupVersion)
      end
    end
  end
end
