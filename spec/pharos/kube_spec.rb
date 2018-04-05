describe Pharos::Kube do

  describe '.parse_resource_file' do
    let(:resource_dir) { File.join(__dir__, '../..', 'lib/pharos/resources')}

    it 'returns resource' do
      resource = described_class.parse_resource_file(resource_dir + '/' + 'host-upgrades/daemonset.yml', {
        arch: double(:arch, name: 'amd64')
      })
      expect(resource.metadata.name).to eq('host-upgrades')
    end

    it 'throws error if resource does not exist' do
      expect {
        described_class.parse_resource_file('foo/bar.yml')
      }.to raise_error(Errno::ENOENT)
    end
  end

  describe '.config_exists?' do
    let(:host) { double(:host, address: '1.1.1.1') }

    it 'returns false if config does not exist' do
      FakeFS do
        expect(described_class.config_exists?(host.address)).to be_falsey
      end
    end

    it 'returns true if config does exist' do
      FakeFS do
        config_dir = File.join(Dir.home, '.pharos')
        FileUtils.mkdir_p(config_dir)
        File.open(File.join(config_dir, host.address), 'w') { |f|
          f.write('asd')
        }
        expect(described_class.config_exists?(host.address)).to be_truthy
      end
    end
  end
end
