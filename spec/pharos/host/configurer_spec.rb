require 'recursive-open-struct'

describe Pharos::Host::Configurer do
  let(:test_config_class) do
    Class.new(described_class) do
      register_config 'test', '1.0.0'
      register_config 'test', '1.1.0'
    end
  end

  let(:host) { double(:host) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  let(:subject) { described_class.new(host, ssh) }

  describe '#register_config' do
    it 'sets os_name and os_version' do
      expect(test_config_class.os_name).to eq('test')
      expect(test_config_class.os_version).to eq('1.1.0')
    end

    it 'registers multiple versions to configs' do
      expect(
        described_class.config_for_os_release(
          Pharos::Configuration::OsRelease.new(id: 'test', version: '1.0.0')
        )
      ).not_to be_nil
      expect(
        described_class.config_for_os_release(
          Pharos::Configuration::OsRelease.new(id: 'test', version: '1.1.0')
        )
      ).not_to be_nil
    end

    it 'registers config class' do
      test_config_class # load
      expect(described_class.configs.last.superclass).to eq(test_config_class)
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

  describe '#insecure_registries' do

    context 'for docker' do
      before do
        allow(host).to receive(:crio?).and_return(false)
      end

      it 'gives properly escaped json array string' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: [
              "registry.foobar.acme",
              "localhost:5000"
            ]
          }
        })
        expect(subject).to receive(:cluster_config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"[\\\"registry.foobar.acme\\\",\\\"localhost:5000\\\"]\"")
      end

      it 'works for empty array' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: []
          }
        })
        expect(subject).to receive(:cluster_config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"[]\"")
      end
    end

    context 'for crio' do
      before do
        allow(host).to receive(:crio?).and_return(true)
      end

      it 'gives properly escaped json array string with brackets stripped' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: [
              "registry.foobar.acme",
              "localhost:5000"
            ]
          }
        })
        expect(subject).to receive(:cluster_config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"\\\"registry.foobar.acme\\\",\\\"localhost:5000\\\"\"")
      end

      it 'works for empty array' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: []
          }
        })
        expect(subject).to receive(:cluster_config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"\"")
      end
    end

  end
end
