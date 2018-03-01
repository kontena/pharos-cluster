require_relative 'base'

module Kupo::Phases
  class ConfigureKubelet < Base

    DROPIN_PATH = "/etc/systemd/system/kubelet.service.d/5-kupo.conf".freeze

    # @param master [Kupo::Configuration::Host]
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
        @ssh.exec("sudo mv #{tmp_file} #{DROPIN_PATH}")
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