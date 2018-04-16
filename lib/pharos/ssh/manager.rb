# frozen_string_literal: true

module Pharos
  module SSH
    class Manager
      def initialize
        @clients = {}
      end

      # @param host [Pharos::Configuration::Host]
      def client_for(host)
        @clients[host] ||= Pharos::SSH::Client.new(host.address, host.user, keys: [host.ssh_key_path]).tap(&:connect)
      end

      def disconnect_all
        @clients.each do |_host, client|
          client.disconnect
        end
      end
    end
  end
end
