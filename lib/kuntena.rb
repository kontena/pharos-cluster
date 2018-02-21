require "clamp"
require_relative "kuntena/autoload"
require_relative "kuntena/version"
require_relative "kuntena/command"
require_relative "kuntena/root_command"

module Kuntena

  # @param host [String]
  # @return [Kubeclient::Client]
  def self.kube_client(host, version = 'v1')
    @kube_client ||= {}
    unless @kube_client[version]
      config = Kubeclient::Config.read(File.join(Dir.home, ".kube/#{host}"))
      if version == 'v1'
        path_prefix = 'api'
      else
        path_prefix = 'apis'
      end
      api_version, api_group = version.split('/').reverse
      @kube_client[version] = Kubeclient::Client.new(
        (config.context.api_endpoint + "/#{path_prefix}/#{api_group}"),
        api_version,
        {
          ssl_options: config.context.ssl_options,
          auth_options: config.context.auth_options
        }
      )
    end
    @kube_client[version]
  end
end
