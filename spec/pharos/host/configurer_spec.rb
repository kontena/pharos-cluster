describe Pharos::Host::Configurer do
  let(:test_config_class) do
    Class.new(described_class) do
      register_config 'test', '1.1.0'
    end
  end

  let(:host) { double(:host) }
  let(:ssh) { double(:ssh) }
  let(:subject) { described_class.new(host, ssh) }

  describe '#register_config' do
    it 'sets os_name and os_version' do
      expect(test_config_class.os_name).to eq('test')
      expect(test_config_class.os_version).to eq('1.1.0')
    end

    it 'registers config class' do
      test_config_class # load
      expect(described_class.configs.last).to eq(test_config_class)
    end
  end

  describe '#supported_os?' do
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

  describe '#update_env_file' do
    let(:host) { instance_double(Pharos::Configuration::Host) }
    let(:ssh) { instance_double(Pharos::SSH::Client) }
    let(:file) { instance_double(Pharos::SSH::RemoteFile) }
    let(:host_env_content) { "PATH=/bin:/usr/local/bin\n" }

    subject { described_class.new(host, ssh) }

    before do
      allow(ssh).to receive(:file).with('/etc/environment').and_return(file)
      allow(ssh).to receive(:disconnect)
      allow(ssh).to receive(:connect)
      allow(file).to receive(:exist?).and_return(true)
      allow(file).to receive(:read).and_return(host_env_content)
      allow(host).to receive(:environment).and_return(config_environment)
    end

    context 'add keys' do
      let(:config_environment) { { 'TEST' => 'foo' } }

      it 'adds a line to /etc/environment' do
        expect(file).to receive(:write).with("TEST=foo\nPATH=/bin:/usr/local/bin\n")
        subject.update_env_file
      end
    end

    context 'modify keys' do
      let(:config_environment) { { 'PATH' => '/bin' } }

      it 'modifies a line in /etc/environment' do
        expect(file).to receive(:write).with("PATH=/bin\n")
        subject.update_env_file
      end
    end

    context 'delete keys' do
      let(:config_environment) { { 'PATH' => nil } }

      it 'removes a line in /etc/environment' do
        expect(file).to receive(:write).with("\n")
        subject.update_env_file
      end
    end
  end
end
