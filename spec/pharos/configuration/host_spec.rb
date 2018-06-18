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
      Pharos::HostConfigManager.load_configs(double(:cluster_config))
      allow(subject).to receive(:os_release).and_return(double(:os_release, id: 'ubuntu', version: '16.04'))
      expect(subject.configurer(double(:ssh))).to be_instance_of(Pharos::Host::UbuntuXenial)
    end
  end

  describe '#crio?' do
    it 'returns true if container runtime is crio' do
      allow(subject).to receive(:container_runtime).and_return('cri-o')
      expect(subject.crio?).to be_truthy
    end

    it 'returns false if container runtime is not crio' do
      allow(subject).to receive(:container_runtime).and_return('docker')
      expect(subject.crio?).to be_falsey
    end
  end

  describe '#docker?' do
    it 'returns true if container runtime is docker' do
      allow(subject).to receive(:docker?).and_return(true)
      expect(subject.docker?).to be_truthy
    end

    it 'returns false if container runtime is not docker' do
      allow(subject).to receive(:container_runtime).and_return('cri-o')
      expect(subject.docker?).to be_falsey
    end
  end
end