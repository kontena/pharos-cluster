# frozen_string_literal: true

require 'k8s-client'

module Pharos
  module Kube
    class Client < K8s::Client
      ConfigurationFileMissing = Class.new(Pharos::Error)

      # @param host [Pharos::Configuration::Host]
      def initialize(host)
        cfg_file = host.transport.file('/etc/kubernetes/admin.conf')
        raise ConfigurationFileMissing unless cfg_file.exist?

        @kube_gw = host.bastion&.host&.gateway || host.gateway
        @kube_gw_port = @kube_gw.open(host.api_address, 6443)

        super(
          K8s::Transport.config(
            K8s::Config.new(
              Pharos::Kube::Config.new(cfg_file.read).tap do |config|
                config.update_server_address(host.api_address)
              end.to_h
            ),
            server: "https://localhost:#{@kube_gw_port}"
          )
        )
      end

      def disconnect
        return unless @kube_gw

        @kube_gw.close(@kube_gw_port)
        @kube_gw_port = nil
        @kube_gw = nil
      end
    end
  end
end
