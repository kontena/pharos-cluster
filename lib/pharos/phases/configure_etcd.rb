# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureEtcd < Base
      CA_PATH = '/etc/pharos/pki'

      register_component(
        Pharos::Phases::Component.new(
          name: 'etcd', version: Pharos::ETCD_VERSION, license: 'Apache License 2.0'
        )
      )

      # @param host [Kupo::Configuration::Host]
      # @param config [Kupo::Configuration]
      def initialize(host, config)
        @host = host
        @config = config
        @ssh = Pharos::SSH::Client.for_host(@host)
      end

      def call
        sync_ca unless @host == @config.etcd_leader

        logger.info(@host.address) { 'Configuring etcd certs ...' }
        peer_index = @config.etcd_hosts.find_index { |h| h == @host }
        exec_script(
          'configure-etcd-certs.sh',
          PEER_IP: @host.private_address || @host.address,
          PEER_NAME: "etcd#{peer_index + 1}",
          ARCH: @host.cpu_arch.name
        )

        logger.info(@host.address) { 'Configuring etcd ...' }
        exec_script(
          'configure-etcd.sh',
          PEER_IP: @host.private_address || @host.address,
          INITIAL_CLUSTER: initial_cluster.join(','),
          ETCD_VERSION: Pharos::ETCD_VERSION,
          KUBE_VERSION: Pharos::KUBE_VERSION,
          ARCH: @host.cpu_arch.name,
          PEER_NAME: "etcd#{peer_index + 1}"
        )
      end

      # @return [Array<String>]
      def initial_cluster
        i = 0
        @config.etcd_hosts.map { |h|
          i += 1
          "etcd#{i}=https://#{h.peer_address}:2380"
        }
      end

      def sync_ca
        return if @ssh.file(File.join(CA_PATH, 'ca.pem')).exist?

        logger.info { 'Pushing certificate authority files to host ...' }
        @ssh.exec!("sudo mkdir -p #{CA_PATH}")
        leader = @config.etcd_leader
        leader_ssh = Pharos::SSH::Client.for_host(leader)
        %w(ca.pem ca-key.pem).each do |file|
          path = File.join(CA_PATH, file)
          ca_crt = leader_ssh.file(path).read
          @ssh.file(path).write(ca_crt)
        end
      end
    end
  end
end
