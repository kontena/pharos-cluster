# frozen_string_literal: true

require_relative 'base'

module Kupo
  module Phases
    class ConfigureKubelet < Base
      DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-kupo.conf"

      # @param host [Kupo::Configuration::Host]
      def initialize(host)
        @host = host
        @ssh = Kupo::SSH::Client.for_host(@host)
      end

      def call
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

      # @return [String, nil]
      def existing_dropin
        file = @ssh.file(DROPIN_PATH)
        file.read if file.exist?
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
