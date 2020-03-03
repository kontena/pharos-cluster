require 'recursive-open-struct'

describe Pharos::Host::Configurer do
  let(:test_config_class) do
    Class.new(described_class) do
      register_config 'test', '1.0.0'
      register_config 'test', '1.1.0'
    end
  end

  let(:host) { instance_double(Pharos::Configuration::Host) }

  before do
    Pharos::Host::Configurer.configurers.delete_if { |c| c.supported_os_releases&.first&.id == 'test' }
    test_config_class
  end

  after do
    Pharos::Host::Configurer.configurers.delete_if { |c| c == test_config_class }
  end

  subject { described_class.new(host) }

  describe '#register_config' do
    it 'registers multiple versions to configs' do
      expect(test_config_class.supported_os_releases.first.version).to eq('1.0.0')
      expect(test_config_class.supported_os_releases.first.id).to eq('test')
      expect(test_config_class.supported_os_releases.last.version).to eq('1.1.0')
      expect(test_config_class.supported_os_releases.last.id).to eq('test')
    end
  end

  describe '#supported_os?' do
    it 'supports multiple versions' do
      expect(
        described_class.for_os_release(
          Pharos::Configuration::OsRelease.new(id: 'test', version: '1.0.0')
        ).new(host)
      ).to be_a test_config_class

      expect(
        described_class.for_os_release(
          Pharos::Configuration::OsRelease.new(id: 'test', version: '1.1.0')
        ).new(host)
      ).to be_a test_config_class

      expect(
        described_class.for_os_release(
          Pharos::Configuration::OsRelease.new(id: 'test', version: '1.2.0')
        )
      ).to be_nil
    end

    it 'registers config class' do
      expect(described_class.configurers.include?(test_config_class)).to be_truthy
    end
  end

  describe '#update_env_file' do
    let(:host) { instance_double(Pharos::Configuration::Host) }
    let(:ssh) { instance_double(Pharos::Transport::SSH) }
    let(:file) { instance_double(Pharos::Transport::TransportFile) }
    let(:host_env_content) { "PATH=/bin:/usr/local/bin\n" }

    subject { described_class.new(host) }

    before do
      allow(host).to receive(:transport).and_return(ssh)
      allow(ssh).to receive(:file).with('/etc/environment').and_return(file)
      allow(file).to receive(:exist?).and_return(true)
      allow(file).to receive(:read).and_return(host_env_content)
      allow(host).to receive(:environment).and_return(config_environment)
    end

    context 'add keys' do
      let(:config_environment) { { 'TEST' => 'foo' } }

      it 'adds a line to /etc/environment' do
        expect(file).to receive(:write).with("TEST=\"foo\"\nPATH=\"/bin:/usr/local/bin\"\n")
        subject.update_env_file
      end
    end

    context 'modify keys' do
      let(:config_environment) { { 'PATH' => '/bin' } }

      it 'modifies a line in /etc/environment' do
        expect(file).to receive(:write).with("PATH=\"/bin\"\n")
        subject.update_env_file
      end
    end

    context 'delete keys' do
      let(:host_env_content) { "PATH=/bin\nTEST=foo\n" }
      let(:config_environment) { { 'PATH' => nil } }

      it 'removes a line in /etc/environment' do
        expect(file).to receive(:write).with("TEST=\"foo\"\n")
        subject.update_env_file
      end
    end
  end

  describe '#insecure_registries' do
    context 'for docker' do
      it 'gives properly escaped json array string' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: [
              "registry.foobar.acme",
              "localhost:5000"
            ]
          }
        })
        expect(subject).to receive(:config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"[\\\"registry.foobar.acme\\\",\\\"localhost:5000\\\"]\"")
      end

      it 'works for empty array' do
        cfg = RecursiveOpenStruct.new({
          container_runtime: {
            insecure_registries: []
          }
        })
        expect(subject).to receive(:config).and_return(cfg)

        expect(subject.insecure_registries).to eq("\"[]\"")
      end
    end
  end

  describe '#host_repositories' do

    default_repos = [Pharos::Configuration::Repository.new(name: "default_repo")]

    it 'returns default repos for empty host repos' do
      allow(host).to receive(:repositories).and_return([])

      expect(subject).to receive(:default_repositories).and_return(default_repos)

      expect(subject.host_repositories[0].name).to eq("default_repo")
    end

    it 'returns default repos for nil host repos' do
      allow(host).to receive(:repositories).and_return(nil)

      expect(subject).to receive(:default_repositories).and_return(default_repos)

      expect(subject.host_repositories[0].name).to eq("default_repo")
    end

    it 'returns default repos for host' do
      allow(host).to receive(:repositories).and_return([Pharos::Configuration::Repository.new(name: "bar")])


      expect(subject.host_repositories[0].name).to eq("bar")
    end
  end
end
