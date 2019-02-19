# frozen_string_literal: true

require 'json'

module Pharos
  module Etcd
    class Client
      CURL = 'sudo curl -sSf --connect-timeout 2 --cacert /etc/pharos/pki/ca.pem --cert /etc/pharos/pki/etcd/client.pem --key /etc/pharos/pki/etcd/client-key.pem https://localhost:2379'

      class Error < StandardError; end

      def initialize(transport)
        @transport = transport
      end

      # @return [Boolean]
      def healthy?
        data = curl("/health")
        data['health'] == 'true'
      rescue Error
        false
      end

      # @return [Array<Hash>]
      def members
        data = curl("/v2/members")
        data['members']
      end

      # @param host [Pharos::Configuration::Host]
      def add_member(host)
        data = {
          peerURLs: ["https://#{host.peer_address}:2380"]
        }
        params = [
          "-X POST",
          "-H 'Content-Type: application/json'",
          "-d @-"
        ]
        curl("/v2/members", params, stdin: JSON.dump(data))
      end

      # @param member_id [String] etcd member id
      def remove_member(member_id)
        curl("/v2/members/#{member_id}", ['-X DELETE'])
      end

      # @param path [String]
      # @param parameters [Array<String>]
      # @param options [Hash]
      def curl(path, parameters = [], options = {})
        result = @transport.exec("#{CURL}#{path} #{parameters.join(' ')}", options)
        raise Error, "path: #{path}, params: #{parameters}, options: #{options}, stderr: #{result.stderr}" if result.error?

        if result.stdout.empty?
          {}
        else
          JSON.parse(result.stdout)
        end
      end
    end
  end
end
