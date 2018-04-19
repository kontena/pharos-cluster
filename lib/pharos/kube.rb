# frozen_string_literal: true

require 'kubeclient'

module Pharos
  module Kube
    autoload :CertManager, 'pharos/kube/cert_manager'
    autoload :Client, 'pharos/kube/client'
    autoload :Resource, 'pharos/kube/resource'
    autoload :Stack, 'pharos/kube/stack'
    autoload :Session, 'pharos/kube/session'

    # @param host [Pharos::Configuration::Host]
    # @return [Pharos::Kube::Session]
    def self.session(host)
      @sessions ||= {}
      @sessions[host] ||= Session.new(host)
    end

    # @param host [Pharos::Configuration::Host]
    # @return [Kubeclient::Config]
    def self.host_config(host)
      Kubeclient::Config.read(host_config_path(host))
    end

    # @param host [Pharos::Configuration::Host]
    # @return [String]
    def self.host_config_path(host)
      File.join(Dir.home, ".pharos/#{host.api_address}")
    end

    # @param host [Pharos::Configuration::Host]
    # @return [Boolean]
    def self.config_exists?(host)
      File.exist?(host_config_path(host))
    end

    # Shortcuts / compatibility:

    def self.apply_stack(host, name, vars = {})
      session(host).stack(name).apply(vars)
    end

    def self.prune_stack(host, name, checksum = nil)
      session(host).stack(name).prune(checksum)
    end
  end
end
