# frozen_string_literal: true

require 'singleton'
require 'net/ssh'
require 'net/ssh/proxy/jump'

module Pharos
  module SSH
    class Manager
      include Singleton

      def initialize
        @clients = {}
      end

      # @param host [Pharos::Configuration::Host]
      def client_for(host)
        return @clients[host] if @clients[host]
        opts = {}
        opts[:keys] = [host.ssh_key_path] if host.ssh_key_path
        opts[:send_env] = [] # override default to not send LC_* envs
        opts[:proxy] = Net::SSH::Proxy::Command.new(host.ssh_proxy_command) if host.ssh_proxy_command
        opts[:bastion] = host.bastion if host.bastion
        @clients[host] = Pharos::SSH::Client.new(host.address, host.user, opts).tap(&:connect)
      end

      def disconnect_all
        @clients.each_value(&:disconnect)
      end
    end
  end
end
