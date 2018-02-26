require_relative 'logging'

module Shokunin::Services
  class ConfigureKubelet
    include Shokunin::Services::Logging

    DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-shokunin.conf".freeze

    # @param master [Shokunin::Configuration::Host]
    def initialize(host)
      @host = host
      @ssh = Shokunin::SSH::Client.for_host(@host)
    end

    def call
      dropin = build_systemd_dropin
      if dropin != existing_dropin
        logger.info { 'Configuring kubelet ...' }
        @ssh.upload(StringIO.new(dropin), '/tmp/kubelet-dropin')
        @ssh.exec("sudo mv /tmp/kubelet-dropin #{DROPIN_PATH}")
        @ssh.exec("sudo systemctl daemon-reload")
        @ssh.exec("sudo systemctl restart kubelet")
      end
    end

    # @return [String]
    def existing_dropin
      @ssh.file_contents(DROPIN_PATH).to_s
    end

    # @return [String]
    def build_systemd_dropin
      config = "[Service]\nEnvironment='KUBELET_EXTRA_ARGS="
      args = []
      node_ip = @host.private_address.nil? ? @host.address : @host.private_address
      args << "--node-ip=#{node_ip}"
      config + args.join(' ') + "'"
    end
  end
end