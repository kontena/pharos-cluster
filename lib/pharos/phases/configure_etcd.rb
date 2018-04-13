# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureEtcd < Pharos::Phase
      title 'Configure etcd'
      CA_PATH = '/etc/pharos/pki'

      register_component(
        Pharos::Phases::Component.new(
          name: 'etcd', version: Pharos::ETCD_VERSION, license: 'Apache License 2.0'
        )
      )

      def call
        sync_ca

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

        mem_storage['etcd-ca'].each do |file, crt|
          path = File.join(CA_PATH, file)
          @ssh.file(path).write(crt)
        end
      end
    end
  end
end
