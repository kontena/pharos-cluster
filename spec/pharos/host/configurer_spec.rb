describe Pharos::Host::Configurer do
  let(:test_config_class) do
    Class.new(described_class) do
      register_config 'test', '1.1.0'
    end
  end

  let(:host) { double(:host) }
  let(:ssh) { double(:ssh) }
  let(:subject) { described_class.new(host, ssh) }

  describe '.register_config' do
    it 'sets os_name and os_version' do
      expect(test_config_class.os_name).to eq('test')
      expect(test_config_class.os_version).to eq('1.1.0')
    end

    it 'registers config class' do
      test_config_class # load
      expect(described_class.configs.last).to eq(test_config_class)
    end
  end

  describe '.supported_os?' do
    it 'returns true if supported' do
      expect(
        test_config_class.supported_os?(
          double(:os_release, id: test_config_class.os_name, version: test_config_class.os_version)
        )
      ).to be_truthy
    end

    it 'returns false if not supported' do
      expect(
        test_config_class.supported_os?(
          double(:os_release, id: test_config_class.os_name, version: '1.2.0')
        )
      ).to be_falsey
    end
  end

  describe '#crio?' do
    it 'returns true if host container runtime is crio' do
      allow(host).to receive(:container_runtime).and_return('cri-o')
      expect(subject.crio?).to be_truthy
    end

    it 'returns false if host container runtime is not crio' do
      allow(host).to receive(:container_runtime).and_return('docker')
      expect(subject.crio?).to be_falsey
    end
  end

  describe '#docker?' do
    it 'returns true if host container runtime is docker' do
      allow(host).to receive(:container_runtime).and_return('docker')
      expect(subject.docker?).to be_truthy
    end

    it 'returns false if host container runtime is not docker' do
      allow(host).to receive(:container_runtime).and_return('cri-o')
      expect(subject.docker?).to be_falsey
    end
  end
end