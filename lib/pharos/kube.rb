# frozen_string_literal: true

require 'kubeclient'

module Pharos
  module Kube
    autoload :CertManager, 'pharos/kube/cert_manager'
    autoload :Client, 'pharos/kube/client'
    autoload :Resource, 'pharos/kube/resource'
    autoload :Stack, 'pharos/kube/stack'
    autoload :Session, 'pharos/kube/session'

    # @param endpoint [String]
    # @return [Pharos::Kube::Session]
    def self.session(endpoint)
      Session.new(endpoint)
    end

    # @param endpoint [String]
    # @return [Kubeclient::Config]
    def self.config(endpoint)
      Kubeclient::Config.read(config_path(endpoint))
    end

    # @return [String]
    def self.config_dir
      File.join(Dir.home, '.pharos')
    end

    # @param endpoint [String]
    # @return [String]
    def self.config_path(endpoint)
      File.join(config_dir, endpoint)
    end

    # @param endpoint [String]
    # @return [Boolean]
    def self.config_exists?(endpoint)
      File.exist?(config_path(endpoint))
    end
  end
end
