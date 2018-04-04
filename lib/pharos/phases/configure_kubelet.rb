# frozen_string_literal: true

require_relative 'base'
require_relative 'component'

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
      # @param config [Pharos::Config]
      def initialize(host, config)
        @host = host
        @config = config
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
        options = []
        options << "Environment='KUBELET_EXTRA_ARGS=#{kubelet_extra_args.join(' ')}'"
        options << "ExecStartPre=-/sbin/swapoff -a"

        "[Service]\n#{options.join("\n")}\n"
      end

      def kubelet_extra_args
        args = []
        node_ip = @host.private_address.nil? ? @host.address : @host.private_address

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=/var/run/crio/crio.sock'
        end

        args << "--node-ip=#{node_ip}"
        args << "--cloud-provider=#{@config.cloud.provider}" if @config.cloud
        args << "--hostname-override=#{@host.hostname}"
        args
      end

      def crio?
        @host.container_runtime == 'cri-o'
      end
    end
  end
end
