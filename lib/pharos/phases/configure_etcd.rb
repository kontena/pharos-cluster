# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureEtcd < Base
      CA_PATH = '/etc/pharos/pki'

      # @param host [Kupo::Configuration::Host]
      # @param config [Kupo::Configuration]
      def initialize(host, config)
        @host = host
        @config = config
        @ssh = Pharos::SSH::Client.for_host(@host)
      end

      def call
        unless @host == @config.etcd_leader
          logger.info { 'Pushing ca.pem to host ...' }
          sync_ca
        end
        i = 0
        initial_cluster = @config.etcd_hosts.map { |h|
          i += 1
          "etcd#{i}=https://#{h.peer_address}:2380"
        }
        peer_index = @config.etcd_hosts.find_index { |h| h == @host }
        exec_script(
          'configure-etcd-certs.sh',
          {
            PEER_IP: @host.private_address || @host.address,
            PEER_NAME: "etcd#{peer_index + 1}"
          }
        )
        exec_script(
          'configure-etcd.sh',
          {
            PEER_IP: @host.private_address || @host.address,
            INITIAL_CLUSTER: initial_cluster.join(','),
            KUBE_VERSION: Pharos::KUBE_VERSION,
            PEER_NAME: "etcd#{peer_index + 1}"
          }
        )
      end

      def sync_ca
        return if @ssh.file_exists?(File.join(CA_PATH, 'ca.pem'))

        @ssh.exec!("sudo mkdir -p #{CA_PATH}")
        leader = @config.etcd_leader
        leader_ssh = Pharos::SSH::Client.for_host(leader)
        %w(ca.pem ca-key.pem).each do |file|
          path = File.join(CA_PATH, file)
          ca_crt = leader_ssh.read_file(path)
          @ssh.write_file(path, ca_crt)
        end
      end
    end
  end
end
