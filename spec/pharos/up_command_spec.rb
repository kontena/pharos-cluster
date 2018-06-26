describe Pharos::UpCommand do
  subject { described_class.new('') }

  describe '#humanize_duration' do
    it 'formats duration as expected' do
      expect(subject.humanize_duration(1019)).to eq "16 minutes 59 seconds"
      expect(subject.humanize_duration(1020)).to eq "17 minutes"
      expect(subject.humanize_duration(1021)).to eq "17 minutes 1 second"
      expect(subject.humanize_duration(1021 + 3600)).to eq "1 hour 17 minutes 1 second"
      expect(subject.humanize_duration(1021 + 7200)).to eq "2 hours 17 minutes 1 second"
    end
  end

  describe '#load_config' do
    let(:arguments) { [] }

    subject do
      subject = described_class.new('')
      subject.parse(arguments)
      subject
    end

    it 'loads the cluster.yml from the current directory' do
      Dir.chdir fixtures_path do
        config = subject.load_config

        expect(config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    it 'reads the file from stdin' do
      config_data = StringIO.new(fixture('cluster.yml'))

      old_stdin = $stdin
      begin
        $stdin = config_data
        config = subject.load_config
      ensure
        $stdin = old_stdin
      end

      expect(config.hosts).to eq [
        Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
      ]
    end

    context 'with --config=.../cluster.yml' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.yml')}"] }

      it 'loads the config' do
        config = subject.load_config

        expect(config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    context 'with --config=.../cluster.yml.erb' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.yml.erb')}"] }

      it 'loads the config' do
        config = subject.load_config

        expect(config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    context 'with --tf-json' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.minimal.yml')}", "--tf-json=#{fixtures_path('terraform/tf.json')}"] }

      it 'loads the config hosts' do
        config = subject.load_config

        expect(config.hosts.map{|h| {address: h.address, role: h.role}}).to eq [
          { address: '147.75.100.11', role: 'master' },
          { address:  "147.75.102.245", role: 'worker' },
          { address:  "147.75.100.113", role: 'worker' },
          { address:  "147.75.100.9", role: 'worker' },
        ]
      end
    end

    context 'with --tf-json including api endpoint' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.minimal.yml')}", "--tf-json=#{fixtures_path('terraform/with_api_endpoint.json')}"] }

      it 'loads the api.endpoint' do
        config = subject.load_config

        expect(config.api.endpoint).to eq 'api.example.com'
      end
    end
  end

  describe '#prompt_continue' do
    let(:prompt) { double(:prompt) }
    let(:config) { double(:config) }

    it 'prompts' do
      allow(subject).to receive(:tty?).and_return(true)
      expect(subject).to receive(:prompt).and_return(prompt)
      expect(prompt).to receive(:yes?)
      subject.prompt_continue(config)
    end

    it 'does not prompt with --yes' do
      allow(subject).to receive(:yes?).and_return(true)
      expect(subject).not_to receive(:prompt)
      subject.prompt_continue(config)
    end

    it 'shows config' do
      allow(subject).to receive(:yes?).and_return(true)
      expect(subject).to receive(:color?).and_return(true).at_least(1).times
      expect(config).to receive(:to_yaml).and_return('---')
      subject.prompt_continue(config)
    end

    it 'shows config without color' do
      allow(subject).to receive(:yes?).and_return(true)
      expect(subject).to receive(:color?).and_return(false).at_least(1).times
      expect(config).to receive(:to_yaml).and_return('---')
      subject.prompt_continue(config)
    end
  end
end
