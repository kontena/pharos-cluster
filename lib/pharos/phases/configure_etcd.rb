# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureEtcd < Pharos::Phase
      title 'Configure etcd'
      CA_PATH = '/etc/pharos/pki'

      register_component(
        name: 'etcd', version: Pharos::ETCD_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| !c.etcd&.endpoints }
      )

      def call
        sync_ca

        logger.info { 'Configuring etcd certs ...' }
        exec_script(
          'configure-etcd-certs.sh',
          PEER_IP: @host.peer_address,
          PEER_NAME: peer_name(@host),
          ARCH: @host.cpu_arch.name
        )

        logger.info { 'Configuring etcd ...' }
        exec_script(
          'configure-etcd.sh',
          PEER_IP: @host.peer_address,
          INITIAL_CLUSTER: initial_cluster.join(','),
          IMAGE_REPO: @config.image_repository,
          ETCD_VERSION: Pharos::ETCD_VERSION,
          KUBE_VERSION: Pharos::KUBE_VERSION,
          ARCH: @host.cpu_arch.name,
          PEER_NAME: peer_name(@host),
          INITIAL_CLUSTER_STATE: initial_cluster_state,
          KUBELET_ARGS: @host.kubelet_args(local_only: true).join(" ")
        )

        host_configurer.ensure_kubelet(
          ARCH: @host.cpu_arch.name,
          KUBE_VERSION: Pharos::KUBE_VERSION,
          KUBELET_ARGS: @host.kubelet_args(local_only: true).join(" "),
          IMAGE_REPO: @config.image_repository
        )
        logger.info { 'Waiting for etcd to respond ...' }
        exec_script(
          'wait-etcd.sh',
          PEER_IP: @host.peer_address
        )
      end

      # @return [Array<String>]
      def initial_cluster
        @config.etcd_hosts.map { |h|
          "#{peer_name(h)}=https://#{h.peer_address}:2380"
        }
      end

      # @param peer [Pharos::Configuration::Host]
      # @return [String]
      def peer_name(peer)
        peer.short_hostname
      end

      def sync_ca
        return if cluster_context['etcd-ca'].keys.all? { |k| ssh.file(File.join(CA_PATH, k)).exist? }

        logger.info { 'Pushing certificate authority files to host ...' }
        ssh.exec!("sudo mkdir -p #{CA_PATH}")

        cluster_context['etcd-ca'].each do |file, crt|
          path = File.join(CA_PATH, file)
          ssh.file(path).write(crt)
        end
      end

      # @return [String,NilClass]
      def initial_cluster_state
        cluster_context['etcd-initial-cluster-state']
      end
    end
  end
end
