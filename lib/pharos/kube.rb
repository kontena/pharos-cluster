# frozen_string_literal: true

module Pharos
  module Kube
    def self.init_logging!
      # rubocop:disable Style/GuardClause
      if Pharos::Logging.debug?
        K8s::Logging.debug!
        K8s::Transport.verbose!
      end
      # rubocop:enable Style/GuardClause
    end

    # @param host [String]
    # @param config [Hash]
    # @return [K8s::Client]
    def self.client(host, config, port = 6443)
      K8s::Client.config(K8s::Config.new(config), server: "https://#{host}:#{port}")
    end

    # @param name [String]
    # @param path [String]
    # @param vars [Hash]
    def self.stack(name, path, **vars)
      Pharos::Kube::Stack.load(name, path, **vars)
    end
  end
end
