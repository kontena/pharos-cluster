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
      expect(test_config_class.supported_os_releases.first.id).to eq('test')
      expect(test_config_class.supported_os_releases.first.version).to eq('1.1.0')
    end

    it 'registers config class' do
      expect(Pharos::Host::Configurer.configurers).to include(test_config_class)
    end
  end

  describe '.supported_os?' do
    it 'returns true if supported' do
      expect(test_config_class.supported?(Pharos::Configuration::OsRelease.new(id: 'test', version: '1.1.0'))).to be_truthy
      expect(test_config_class.supported?('test', '1.1.0')).to be_truthy
    end

    it 'returns false if not supported' do
      expect(test_config_class.supported?('test', '1.2.0')).to be_falsey
    end
  end
end
