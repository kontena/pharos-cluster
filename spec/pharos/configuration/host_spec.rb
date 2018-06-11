require 'pharos/config'

describe Pharos::Configuration::Host do

  let(:subject) do
    described_class.new(
      address: '192.168.100.100',
      role: 'master',
      user: 'root'
    )
  end

  describe '#configurer' do
    it 'returns nil on non-supported os release' do
      allow(subject).to receive(:os_release).and_return(double(:os_release, id: 'foo', version: 'bar'))
      expect(subject.configurer(double(:ssh))).to be_nil
    end

    it 'returns os release when supported' do
      Pharos::HostConfigManager.load_configs
      allow(subject).to receive(:os_release).and_return(double(:os_release, id: 'ubuntu', version: '16.04'))
      expect(subject.configurer(double(:ssh))).to be_instance_of(Pharos::Host::UbuntuXenial)
    end
  end
end