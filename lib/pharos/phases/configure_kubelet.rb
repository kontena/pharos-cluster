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
        @ssh.file(DROPIN_PATH).write(dropin)
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
        args = []
        node_ip = @host.private_address.nil? ? @host.address : @host.private_address

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=/var/run/crio/crio.sock'
        end

        args << '--read-only-port=0'
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
