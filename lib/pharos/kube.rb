# frozen_string_literal: true

require 'k8s-client'

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

    # @param name [String]
    # @param path [String]
    # @param vars [Hash]
    def self.stack(name, path, **vars)
      Pharos::Kube::Stack.load(name, path, **vars)
    end
  end
end
