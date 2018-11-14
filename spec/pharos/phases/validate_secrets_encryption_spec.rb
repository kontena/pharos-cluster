require "pharos/phases/validate_secrets_encryption"

describe Pharos::Phases::ValidateSecretsEncryption do
  let(:config_hosts_count) { 1 }
  let(:host) { Pharos::Configuration::Host.new(role: 'master', address: 'test', private_address: 'private' ) }

  let(:config) { Pharos::Config.new(
    hosts: [host],
    network: {
      service_cidr: '1.2.3.4/16',
      pod_network_cidr: '10.0.0.0/16'
    },
    addons: {},
    etcd: {}
  ) }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, config: config) }

  before do
    allow(host).to receive(:ssh).and_return(ssh)
  end

  describe '#existing_keys_valid?' do
    let(:file) { instance_double(Pharos::SSH::RemoteFile) }

    before do
      allow(ssh).to receive(:file).with('/etc/pharos/secrets-encryption/config.yml').and_return(file)
    end

    it 'returns false if no config file existing' do
      expect(file).to receive(:exist?).and_return(false)

      expect(subject.existing_keys_valid?).to be_falsey
    end

    it 'returns true if aescbc keys configured' do
      expect(file).to receive(:exist?).and_return(true)
      expect(file).to receive(:read).and_return(fixture("secrets_cfg.yaml"))
      expect(subject.existing_keys_valid?).to be_truthy
    end
  end
end
