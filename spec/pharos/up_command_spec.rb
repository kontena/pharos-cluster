describe Pharos::UpCommand do
  subject { described_class.new('') }
  let(:config) { double(:config) }

  let(:yaml) { { 'hosts' => [] } }
  let(:cfg) { YAML.dump(yaml) }
  let(:erb_cfg) { YAML.dump(yaml.merge('erb' => '<%= 5+5 %>')) }

  context 'configuration file' do
    before do
      allow(subject).to receive(:configure).and_return(true)
    end

    context 'default from cluster.yml in current directory' do
      it 'reads the cluster.yml from current directory' do
        allow(Dir).to receive(:glob).and_return(['cluster.yml'])
        expect(File).to receive(:read).with('cluster.yml').and_return(cfg)
        subject.run([])
      end

      it 'reads cluster.yml.erb from current directory' do
        allow(Dir).to receive(:glob).and_return(['cluster.yml.erb'])
        expect(File).to receive(:read).with('cluster.yml.erb').and_return(erb_cfg)
        expect(subject).to receive(:validate_config) do |cfg|
          expect(cfg).to match hash_including('erb' => "10")
        end.and_return(yaml)
        subject.run([])
      end
    end

    context 'using --config' do
      it 'reads the file from the specified location' do
        expect(File).to receive(:realpath).with('/tmp/test.yml').and_return('test.yml')
        expect(File).to receive(:read).with('test.yml').and_return(cfg)
        subject.run(['--config', '/tmp/test.yml'])
      end
    end

    context 'from stdin' do
      it 'reads the file from stdin' do
        expect(File).not_to receive(:realpath)
        expect(subject).to receive(:validate_config).with(yaml).and_return(yaml)
        old_stdin = $stdin
        begin
          $stdin = StringIO.new(cfg)
          subject.run([])
        ensure
          $stdin = old_stdin
        end
      end
    end
  end
end
