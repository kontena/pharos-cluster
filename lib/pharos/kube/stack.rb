# frozen_string_literal: true

require 'k8s-client'

module Pharos
  module Kube
    class Stack < K8s::Stack
      # custom labels
      LABEL = 'pharos.kontena.io/stack'
      CHECKSUM_ANNOTATION = 'pharos.kontena.io/stack-checksum'

      # Load stack with resources from path containing erb-templated YAML files
      #
      # @param path [String]
      # @param name [String]
      # @param vars [Hash]
      def self.load(name, path, **vars)
        path = Pathname.new(path).freeze
        files = Pathname.glob(path.join('*.{yml,yaml,yml.erb,yaml.erb}')).sort_by(&:to_s)
        resources = files.flat_map do |file|
          Pharos::YamlFile.new(file).load_stream(name: name, **vars) do |doc|
            K8s::Resource.new(doc)
          end
        end.select do |r|
          # Take in only resources that are valid kube resources
          r.kind && r.apiVersion
        end

        new(name, resources)
      end
    end
  end
end
