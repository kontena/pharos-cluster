# frozen_string_literal: true

require 'kubeclient'

module Pharos
  module Kube
    autoload :CertManager, 'pharos/kube/cert_manager'
    autoload :Client, 'pharos/kube/client'
    autoload :Resource, 'pharos/kube/resource'
    autoload :Stack, 'pharos/kube/stack'
    autoload :Session, 'pharos/kube/session'

    RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, 'resources'))).freeze

    # @param host [String]
    # @return [Kubeclient::Client]
    def self.client(host, version = 'v1')
      @kube_client ||= {}
      unless @kube_client[version]
        config = host_config(host)
        path_prefix = version == 'v1' ? 'api' : 'apis'
        api_version, api_group = version.split('/').reverse
        @kube_client[version] = Pharos::Kube::Client.new(
          (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
          api_version,
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        )
      end
      @kube_client[version]
    end

    # @param host [String]
    # @return [Pharos::Kube::Session]
    def self.session(host)
      @sessions ||= {}
      @sessions[host] ||= Session.new(host)
    end

    # @param host [String]
    # @return [Kubeclient::Config]
    def self.host_config(host)
      Kubeclient::Config.read(host_config_path(host))
    end

    # @param host [String]
    # @return [String]
    def self.host_config_path(host)
      File.join(Dir.home, ".pharos/#{host}")
    end

    # @param host [String]
    # @return [Boolean]
    def self.config_exists?(host)
      File.exist?(host_config_path(host))
    end

    # Shortcuts / compatibility:

    def self.apply_stack(host, name, vars = {})
      session(host).stack(name, RESOURCE_PATH, vars).apply
    end

    def self.apply_resource(host, name, vars = {})
      session(host).stack(name, RESOURCE_PATH, vars).apply
    end

    def self.prune_stack(host, name, checksum)
      session(host).stack(name, RESOURCE_PATH).prune(checksum)
    end
  end
end
