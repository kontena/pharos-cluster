# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureKubelet < Base
      register_component(
        Pharos::Phases::Component.new(
          name: 'kubernetes', version: Pharos::KUBE_VERSION, license: 'Apache License 2.0'
        )
      )

      DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-pharos.conf"

      # @param host [Pharos::Configuration::Host]
      def initialize(host)
        @host = host
        @ssh = Pharos::SSH::Client.for_host(@host)
      end

      def call
        configure_cni
        configure_kube

        logger.info { 'Configuring kubelet ...' }
        ensure_dropin(build_systemd_dropin)
      end

      # @param dropin [String]
      def ensure_dropin(dropin)
        return if dropin == existing_dropin

        @ssh.exec!("sudo mkdir -p /etc/systemd/system/kubelet.service.d/")
        @ssh.write_file(DROPIN_PATH, dropin)
        @ssh.exec!("sudo systemctl daemon-reload")
        @ssh.exec!("sudo systemctl restart kubelet")
      end

      def configure_kube
        logger.info { "Configuring Kubernetes packages ..." }
        exec_script(
          'configure-kube.sh',
          KUBE_VERSION: Pharos::KUBE_VERSION,
          KUBEADM_VERSION: Pharos::KUBEADM_VERSION,
          ARCH: @host.cpu_arch.name
        )
      end

      def configure_cni
        exec_script('configure-weave-cni.sh')
      end

      # @return [String, nil]
      def existing_dropin
        @ssh.read_file(DROPIN_PATH) if @ssh.file_exists?(DROPIN_PATH)
      end

      # @return [String]
      def build_systemd_dropin
        config = "[Service]\nEnvironment='KUBELET_EXTRA_ARGS="
        args = kubelet_extra_args
        node_ip = @host.private_address.nil? ? @host.address : @host.private_address
        args << "--node-ip=#{node_ip}"
        config = config + args.join(' ') + "'"
        config + "\nExecStartPre=-/sbin/swapoff -a"
      end

      def kubelet_extra_args
        return [] unless crio?
        %w(
          --container-runtime=remote
          --runtime-request-timeout=15m
          --container-runtime-endpoint=/var/run/crio/crio.sock
        )
      end

      def crio?
        @host.container_runtime == 'cri-o'
      end
    end
  end
end
