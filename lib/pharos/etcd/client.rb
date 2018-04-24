# frozen_string_literal: true

require 'json'

module Pharos
  module Etcd
    class Client
      CURL = 'sudo curl -sSf --connect-timeout 2 --cacert /etc/pharos/pki/ca.pem --cert /etc/pharos/pki/etcd/client.pem --key /etc/pharos/pki/etcd/client-key.pem https://localhost:2379'

      class Error; end

      def initialize(ssh)
        @ssh = ssh
      end

      # @return [Boolean]
      def healthy?
        result = @ssh.exec("#{CURL}/health")
        return false if result.error?

        data = JSON.parse(result.stdout)
        data['health'] == 'true'
      end

      # @return [Array<Hash>]
      def members
        result = @ssh.exec("#{CURL}/v2/members")
        raise Error, "Cannot fetch etcd members" if result.error?

        JSON.parse(result.stdout)['members']
      end

      # @param host [Pharos::Configuration::Host]
      def add_member(host)
        data = {
          peerURLs: ["https://#{host.peer_address}:2380"]
        }
        @ssh.exec!("#{CURL}/v2/members -X POST -H 'Content-Type: application/json' -d @-", stdin: JSON.dump(data))
      end

      # @param member_id [String] etcd member id
      def remove_member(member_id)
        @ssh.exec!("#{CURL}/v2/members/#{member_id} -X DELETE")
      end
    end
  end
end
