
module Pharos
  module SSH
    class Manager
      def initialize
        @clients = {}
      end

      # @param host [Pharos::Configuration::Host]
      def client_for(host)
        @clients[host] ||= Pharos::SSH::Client.new(host.address, host.user, keys: [host.ssh_key_path]).tap do |client|
          client.connect
        end
      end

      # @param hosts [Array<Pharos::Configuration::Host>]
      # @return [Array<...>]
      def with_hosts(hosts)
        threads = hosts.map do |host|
          # from the main thread
          client = client_for(host)

          Thread.new do
            begin
              yield(host, client)
            rescue => exc
              puts " [#{host}] #{exc.class}: #{exc.message}"
              raise
            end
          end
        end

        threads.map { |thread| thread.value }
      end

      def disconnect_all
        @clients.each do |host, client|
          client.disconnect
        end
      end
    end
  end
end
