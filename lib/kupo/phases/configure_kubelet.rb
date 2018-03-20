# frozen_string_literal: true

require_relative 'base'

module Kupo::Phases
  class ConfigureKubelet < Base
    DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-kupo.conf"

    # @param host [Kupo::Configuration::Host]
    def initialize(host)
      @host = host
      @ssh = Kupo::SSH::Client.for_host(@host)
    end

    def call
      logger.info { 'Configuring kubelet ...' }
      dropin = build_systemd_dropin
      if dropin != existing_dropin
        tmp_file = File.join('/tmp', SecureRandom.hex(16))
        @ssh.upload(StringIO.new(dropin), tmp_file)
        @ssh.exec!("sudo mkdir -p /etc/systemd/system/kubelet.service.d/")
        @ssh.exec!("sudo mv #{tmp_file} #{DROPIN_PATH}")
        @ssh.exec!("sudo systemctl daemon-reload")
        @ssh.exec!("sudo systemctl restart kubelet")
      end
    end

    # @return [String, nil]
    def existing_dropin
      @ssh.file_contents(DROPIN_PATH) if @ssh.file_exists?(DROPIN_PATH)
    end

    # @return [String]
    def build_systemd_dropin
      config = "[Service]\nEnvironment='KUBELET_EXTRA_ARGS="
      if crio?
        args = [
          '--container-runtime=remote',
          '--runtime-request-timeout=15m',
          '--container-runtime-endpoint=/var/run/crio/crio.sock'
        ]
      else
        args = []
      end
      node_ip = @host.private_address.nil? ? @host.address : @host.private_address
      args << "--node-ip=#{node_ip}"
      config = config + args.join(' ') + "'"
      config + "\nExecStartPre=-/sbin/swapoff -a"
    end

    def crio?
      @host.container_runtime == 'cri-o'
    end
  end
end
