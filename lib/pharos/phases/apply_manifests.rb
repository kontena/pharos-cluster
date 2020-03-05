# frozen_string_literal: true

module Pharos
  module Phases
    class ApplyManifests < Pharos::Phase
      title "Apply configured kubernetes manifests"

      def call
        manifest_paths = config.manifests.to_a
        logger.info "Applying configured manifests: "
        manifest_paths.each do |path|
          logger.info "  - #{path}"
        end
        manifests = []
        manifest_paths.each { |manifest_path| manifests += load_manifests(manifest_path) }
        stack = Pharos::Kube::Stack.new("pharos-manifests", manifests)
        stack.apply(kube_client)
      end

      # Load resources from path containing erb-templated YAML files
      #
      # @param path [String]
      # @return [Array<K8s::Resource>]
      def load_manifests(path)
        path = Pathname.new(path).freeze
        files = if File.file?(path)
                  [path]
                else
                  Pathname.glob(path.join('*.{yml,yaml,yml.erb,yaml.erb}')).sort_by(&:to_s)
                end
        resources = files.flat_map do |file|
          Pharos::YamlFile.new(file).load_stream do |doc|
            K8s::Resource.new(doc)
          end
        end.select do |r|
          # Take in only resources that are valid kube resources
          r.kind && r.apiVersion
        end

        resources
      end
    end
  end
end
