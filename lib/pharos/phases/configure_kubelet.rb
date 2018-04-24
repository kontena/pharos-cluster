# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureKubelet < Pharos::Phase
      title "Configure kubelet"

      register_component(
        Pharos::Phases::Component.new(
          name: 'kubernetes', version: Pharos::KUBE_VERSION, license: 'Apache License 2.0'
        )
      )

      DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-pharos.conf"
      CLOUD_CONFIG_DIR = "/etc/pharos/kubelet"
      CLOUD_CONFIG_FILE = (CLOUD_CONFIG_DIR + '/cloud-config')

      def call
        configure_cni
        push_cloud_config if @config.cloud&.config
        configure_kubelet_proxy if @host.role == 'worker'
        configure_kube

        logger.info { 'Configuring kubelet ...' }
        ensure_dropin(build_systemd_dropin)
      end

      def push_cloud_config
        @ssh.exec!("sudo mkdir -p #{CLOUD_CONFIG_DIR}")
        @ssh.file(CLOUD_CONFIG_FILE).write(File.open(File.expand_path(@config.cloud.config)))
      end

      # @param dropin [String]
      def ensure_dropin(dropin)
        return if dropin == existing_dropin

        @ssh.exec!("sudo mkdir -p /etc/systemd/system/kubelet.service.d/")
        @ssh.file(DROPIN_PATH).write(dropin)
        @ssh.exec!("sudo systemctl daemon-reload")
        @ssh.exec!("sudo systemctl restart kubelet")
      end

      def configure_kubelet_proxy
        exec_script(
          'configure-kubelet-proxy.sh',
          KUBE_VERSION: Pharos::KUBE_VERSION,
          ARCH: @host.cpu_arch.name,
          MASTER_HOSTS: @config.master_hosts.map(&:peer_address).join(','),
          KUBELET_ARGS: @host.kubelet_args(local_only: true).join(" ")
        )
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
        file = @ssh.file(DROPIN_PATH)
        file.read if file.exist?
      end

      # @return [String]
      def build_systemd_dropin
        options = []
        options << "Environment='KUBELET_EXTRA_ARGS=#{kubelet_extra_args.join(' ')}'"
        options << "Environment='KUBELET_DNS_ARGS=#{kubelet_dns_args.join(' ')}'"
        options << "ExecStartPre=-/sbin/swapoff -a"

        "[Service]\n#{options.join("\n")}\n"
      end

      # @return [Array<String>]
      def kubelet_dns_args
        [
          "--cluster-dns=#{@config.network.dns_service_ip}",
          "--cluster-domain=cluster.local"
        ]
      end

      # @return [Array<String>]
      def kubelet_extra_args
        args = @host.kubelet_args
        args << "--cloud-provider=#{@config.cloud.provider}" if @config.cloud
        args << "--cloud-config=#{CLOUD_CONFIG_FILE}" if @config.cloud&.config
        args
      end
    end
  end
end
