require "pharos/phases/configure_secrets_encryption"

describe Pharos::Phases::ConfigureSecretsEncryption do
  let(:master) { Pharos::Configuration::Host.new(address: 'test', private_address: 'private', role: 'master') }
  let(:host) { Pharos::Configuration::Host.new(role: 'worker') }

  let(:config) do
    Pharos::Config.new(
      hosts: [host],
      network: {
        service_cidr: '1.2.3.4/16',
        pod_network_cidr: '10.0.0.0/16'
      },
      addons: {},
      etcd: {}
    )
  end

  let(:master_ssh) { instance_double(Pharos::SSH::Client) }
  let(:file) { instance_double(Pharos::SSH::RemoteFile) }
  let(:secrets_config) { 'hello' }
  let(:cluster_context) { { 'secrets_encryption' => secrets_config } }

  subject { described_class.new(master, config: config) }

  before do
    allow(subject).to receive(:cluster_context).and_return(cluster_context)
    allow(master).to receive(:ssh).and_return(master_ssh)
    allow(master_ssh).to receive(:file).with('/etc/pharos/secrets-encryption/config.yml').and_return(file)
  end

  describe '#call' do
    it 'writes config file' do
      expect(master_ssh).to receive(:exec!).with(/test.+?install/).and_return(true)
      expect(file).to receive(:write).with('hello').and_return(true)
      expect(file).to receive(:chmod).with('0700').and_return(true)
      subject.call
    end
  end
end
