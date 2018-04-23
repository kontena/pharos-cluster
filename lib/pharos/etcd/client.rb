# frozen_string_literal: true
require 'json'

module Pharos
  module Etcd
    class Client
      CURL = 'sudo curl -s --connect-timeout 2 --cacert /etc/pharos/pki/ca.pem --cert /etc/pharos/pki/etcd/client.pem --key /etc/pharos/pki/etcd/client-key.pem https://localhost:2379'

      def initialize(ssh)
        @ssh = ssh
      end

      def healthy?
        response = @ssh.exec!("#{CURL}/health")
        response.stdout == '{"health": "true"}'
      rescue
        false
      end

      # @return [Array<Hash>]
      def members
        result = @ssh.exec("#{CURL}/v2/members")
        JSON.parse(result.stdout)['members']
      rescue JSON::ParserError
        []
      end

      # @param host [Pharos::Configuration::Host]
      def add_member(host)
        @ssh.exec!("#{CURL}/v2/members -X POST -H 'Content-Type: application/json' -d '{\"peerURLs\":[\"https://#{host.peer_address}:2380\"]}'")
      end
    end
  end
end