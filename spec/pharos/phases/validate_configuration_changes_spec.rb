require 'pharos/config'
require 'pharos/phases/validate_configuration_changes'

describe Pharos::Phases::ValidateConfigurationChanges do
  let(:host) {
    double(
      :host,
      address: '10.10.10.2',
      user: 'root',
      ssh_key_path: '~/.ssh/id_rsa.pub',
      container_runtime: 'docker',
      hostname: 'node-1'
    )
  }
  let(:config) { Pharos::Config.new(hosts: [{address: '10.0.0.1', role: 'master'}], network: { provider: 'new' }) }
  let(:old_config) { Pharos::Config.new(hosts: [{address: '10.0.0.1', role: 'master'}], network: { provider: 'old' }) }
  let(:cluster_context) { { 'previous-config' => old_config } }

  let(:subject) { described_class.new(config.hosts.first, cluster_context: cluster_context, config: config) }

  describe '#apply?' do
    it 'should only be applied when cluster context contains a previous config' do
      expect(described_class.apply?(nil, { 'previous-config' => 'test' })).to be_truthy
      expect(described_class.apply?(nil, {})).to be_falsey
    end
  end

  describe '#call' do
    it 'detects network provider change' do
      expect{subject.call}.to raise_error(Pharos::ConfigError, /can't change network.provider from old to new/)
    end
  end
end
