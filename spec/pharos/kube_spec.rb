describe Pharos::Kube do

  describe '.parse_resource_file' do
    it 'returns resource' do
      resource = described_class.parse_resource_file(described_class.resource_path('ingress-nginx/03-role.yml'))
      expect(resource.metadata.name).to eq('nginx-ingress-role')
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
        expect(described_class.config_exists?(host)).to be_falsey
      end
    end

    it 'returns true if config does exist' do
      FakeFS do
        config_dir = File.join(Dir.home, '.pharos')
        FileUtils.mkdir_p(config_dir)
        File.open(File.join(config_dir, host.address), 'w') { |f|
          f.write('asd')
        }
        expect(described_class.config_exists?(host)).to be_truthy
      end
    end
  end

  describe '.resource_files' do
    it 'returns a list of .yml and .yml.erb files in the stack directory' do
      file_list = described_class.resource_files('ingress-nginx')
      expect(file_list.select { | f| f.fnmatch('*.yml.erb') }).not_to be_empty
      expect(file_list.select { | f| f.fnmatch('*.yml') }).not_to be_empty
    end
  end
end