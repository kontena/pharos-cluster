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
        expect(subject).to receive(:build_config) do |cfg|
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
        expect(subject).to receive(:build_config).with(yaml).and_return(yaml)
        old_stdin = $stdin
        begin
          $stdin = StringIO.new(cfg)
          subject.run([])
        ensure
          $stdin = old_stdin
        end
      end
    end

    context '#humanize_duration' do
      it 'formats duration as expected' do
        expect(subject.humanize_duration(1019)).to eq "16 minutes 59 seconds"
        expect(subject.humanize_duration(1020)).to eq "17 minutes"
        expect(subject.humanize_duration(1021)).to eq "17 minutes 1 second"
        expect(subject.humanize_duration(1021 + 3600)).to eq "1 hour 17 minutes 1 second"
        expect(subject.humanize_duration(1021 + 7200)).to eq "2 hours 17 minutes 1 second"
      end
    end
  end

  describe '#load_terraform' do
    let(:config) { Hash.new }

    it 'loads hosts from json file' do
      subject.load_terraform(fixtures_dir('terraform/tf.json'), config)
      expect(config['hosts'].size).to eq(4)
    end

    it 'loads api.endpoint from json file' do
      subject.load_terraform(fixtures_dir('terraform/with_api_endpoint.json'), config)
      expect(config.dig('api', 'endpoint')).to eq('api.example.com')
    end
  end
end
