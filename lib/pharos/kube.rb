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

    # @return [String]
    def self.config_dir
      File.join(Dir.home, '.pharos')
    end

    # @param host [Pharos::Configuration::Host]
    # @return [String]
    def self.host_config_path(host)
      File.join(config_dir, host.api_address)
    end

    # @param host [Pharos::Configuration::Host]
    # @return [Boolean]
    def self.host_config_exists?(host)
      File.exist?(host_config_path(host))
    end
  end
end
