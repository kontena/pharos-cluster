require "pharos/phases/generate_secrets_encryption_keys"

describe Pharos::Phases::GenerateSecretsEncryptionKeys do
  let(:master) { Pharos::Configuration::Host.new(address: 'test', private_address: 'private', role: 'master') }
  let(:config_hosts_count) { 1 }

  let(:config) { Pharos::Config.new(
    hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new(role: 'worker') },
    network: {
      service_cidr: '1.2.3.4/16',
      pod_network_cidr: '10.0.0.0/16'
    },
    addons: {},
    etcd: {}
  ) }
  let(:context) { double(:context) }

  subject { described_class.new(master, config: config) }

  describe '#call' do
    it 'updates cluster_context' do
      expect(subject).to receive(:generate_keys).and_return("test")
      expect(subject).to receive(:cluster_context).and_return(context)
      expect(context).to receive(:[]=).with('secrets_encryption', 'test')
      subject.call
    end
  end

  describe '#generate_keys' do
    it 'creates valid keys' do
      result = YAML.load(subject.generate_keys)
      key = result['resources'].first['providers'].first['aescbc']['keys'].first
      expect(key['name']).to eq 'key1'
      expect(key['secret'].empty?).to be_falsey
      expect{Base64.strict_decode64(key['secret'])}.not_to raise_error
    end
  end
end
