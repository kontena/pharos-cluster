# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureKubelet < Pharos::Phase
      title "Configure kubelet"

      register_component(
        name: 'kubernetes', version: Pharos::KUBE_VERSION, license: 'Apache License 2.0'
      )

      register_component(
        name: 'coredns', version: Pharos::COREDNS_VERSION, license: 'Apache License 2.0'
      )

      register_component(
        name: 'pharos-kubelet-proxy', version: Pharos::KUBELET_PROXY_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| !c.worker_hosts.empty? }
      )

      DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/11-pharos.conf"
      CLOUD_CONFIG_DIR = "/etc/pharos/kubelet"
      CLOUD_CONFIG_FILE = (CLOUD_CONFIG_DIR + '/cloud-config')

      def call
        push_cloud_config if @config.cloud&.config
        configure_kubelet_proxy if @host.role == 'worker'
        configure_kube

        if host.new?
          logger.info { 'Configuring kubelet ...' }
        else
          logger.info { 'Reconfiguring kubelet ...' }
        end
        ensure_dropin(build_systemd_dropin)
      end

      def push_cloud_config
        transport.exec!("sudo mkdir -p #{CLOUD_CONFIG_DIR}")
        transport.file(CLOUD_CONFIG_FILE).write(File.open(File.expand_path(@config.cloud.config)))
      end

      # @param dropin [String]
      def ensure_dropin(dropin)
        return if dropin == existing_dropin

        transport.exec!("sudo mkdir -p /etc/systemd/system/kubelet.service.d/")
        transport.file(DROPIN_PATH).write(dropin)
        transport.exec!("sudo systemctl daemon-reload")
        transport.exec!("sudo systemctl restart kubelet")
      end

      def configure_kubelet_proxy
        exec_script(
          'configure-kubelet-proxy.sh',
          KUBE_VERSION: Pharos::KUBE_VERSION,
          IMAGE_REPO: @config.image_repository,
          ARCH: @host.cpu_arch.name,
          VERSION: Pharos::KUBELET_PROXY_VERSION,
          MASTER_HOSTS: master_addresses.join(',')
        )
        host_configurer.ensure_kubelet(
          KUBELET_ARGS: @host.kubelet_args(local_only: true).join(" "),
          KUBE_VERSION: Pharos::KUBE_VERSION,
          CNI_VERSION: Pharos::CNI_VERSION,
          ARCH: @host.cpu_arch.name,
          IMAGE_REPO: @config.image_repository
        )
        exec_script(
          'wait-kubelet-proxy.sh'
        )
      end

      # @return [Array<String>]
      def master_addresses
        @config.master_hosts.map { |master| master.peer_address_for(@host) }
      end

      def configure_kube
        logger.info { "Configuring Kubernetes packages ..." }
        exec_script(
          'configure-kube.sh'
        )
        host_configurer.install_kube_packages(
          KUBE_VERSION: Pharos::KUBE_VERSION,
          KUBEADM_VERSION: Pharos::KUBEADM_VERSION,
          ARCH: @host.cpu_arch.name
        )
      end

      # @return [String, nil]
      def existing_dropin
        file = transport.file(DROPIN_PATH)
        file.read if file.exist?
      end

      # @return [String]
      def build_systemd_dropin
        options = []
        options << "Environment='KUBELET_EXTRA_ARGS=#{kubelet_extra_args.join(' ')}'"

        if @config.control_plane&.use_proxy && @host.environment
          @host.environment.each do |key, value|
            next unless key.downcase.end_with?('_proxy')

            options << "Environment='#{key}=#{value}'"
          end
        end

        options << "ExecStartPre=-/sbin/swapoff -a"

        "[Service]\n#{options.join("\n")}\n"
      end

      # @return [Array<String>]
      def kubelet_extra_args
        args = []
        args += @host.kubelet_args(local_only: false, cloud_provider: @config.cloud&.provider)

        if @host.resolvconf.systemd_resolved_stub
          # use upstream resolvers instead of systemd stub resolver at localhost for `dnsPolicy: Default` pods
          # XXX: kubeadm also handles this?
          args << '--resolv-conf=/run/systemd/resolve/resolv.conf'
        elsif @host.resolvconf.nameserver_localhost
          fail "Host has /etc/resolv.conf configured with localhost as a resolver"
        end

        args << "--pod-infra-container-image=#{@config.image_repository}/pause:3.1"
        args << "--cloud-provider=#{@config.cloud.provider}" if @config.cloud
        args << "--cloud-config=#{CLOUD_CONFIG_FILE}" if @config.cloud&.config
        args
      end
    end
  end
end
