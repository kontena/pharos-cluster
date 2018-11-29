require "pharos/phases/upgrade_master"

describe Pharos::Phases::UpgradeMaster do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config) { Pharos::Config.new(
      hosts: [master],
      network: {},
      addons: {},
      etcd: {}
  ) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  let(:file) { instance_double(Pharos::SSH::RemoteFile) }

  before do
    allow(master).to receive(:ssh).and_return(ssh)
    allow(ssh).to receive(:file).and_return(file)
  end

  subject { described_class.new(master, config: config) }

  describe '#current_apiserver_version' do
    let(:apiserver_yaml) do
      YAML.dump(
        'spec' => {
          'containers' => [
            {
              'name' => 'kube-apiserver',
              'image' => 'registry.pharos.sh/kontenapharos/kube-apiserver:v1.12.2'
            }
          ]
        }
      )
    end

    before do
      allow(file).to receive(:exist?).and_return(true)
      allow(file).to receive(:read).and_return(apiserver_yaml)
    end

    it 'returns the version number from kube-apiserver.yaml' do
      expect(subject.current_apiserver_version).to eq '1.12.2'
    end
  end
end
