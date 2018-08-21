# frozen_string_literal: true

require 'k8s-client'
require_relative 'kube/config'

module Pharos
  module Kube
    def self.init_logging!
      # rubocop:disable Style/GuardClause
      if ENV['DEBUG']
        K8s::Logging.debug!
        K8s::Transport.verbose!
      end
      # rubocop:enable Style/GuardClause
    end

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
        files = Pathname.glob(path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
        resources = files.map do |file|
          K8s::Resource.new(Pharos::YamlFile.new(file).load(name: name, **vars))
        end

        new(name, resources)
      end
    end

    # @param host [String]
    # @param config [K8s::Config]
    # @return [K8s::Client]
    def self.client(host, config)
      K8s::Client.config(config, server: "https://#{host}:6443")
    end

    # @param name [String]
    # @param path [String]
    # @param vars [Hash]
    def self.stack(name, path, **vars)
      Pharos::Kube::Stack.load(name, path, **vars)
    end
  end
end
