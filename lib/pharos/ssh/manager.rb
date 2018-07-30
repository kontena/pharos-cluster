# frozen_string_literal: true

module Pharos
  module SSH
    class Manager
      def initialize
        @clients = {}
      end

      # @param host [Pharos::Configuration::Host]
      def client_for(host)
        return @clients[host] if @clients[host]
        opts = {}
        opts[:keys] = [host.ssh_key_path] if host.ssh_key_path
        @clients[host] = Pharos::SSH::Client.new(host.address, host.user, opts).tap(&:connect)
      end

      def disconnect_all
        @clients.each_value(&:disconnect)
      end
    end
  end
end
