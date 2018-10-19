describe Pharos::CommandOptions::ConfigLoadingOptions do
  let(:arguments) { [] }

  subject do
    Class.new(Pharos::Command) do
      include Pharos::CommandOptions::ConfigLoadingOptions

      def config
        @config ||= load_config
      end
    end.new('').tap do |subject|
      subject.parse(arguments)
    end
  end

  describe '#load_config' do
    it 'loads the cluster.yml from the current directory' do
      Dir.chdir fixtures_path do
        expect(subject.config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    it 'reads the file from stdin' do
      config_data = StringIO.new(fixture('cluster.yml'))

      old_stdin = $stdin
      begin
        $stdin = config_data
        config = subject.config
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
        expect(subject.config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    context 'with --config=.../cluster.yml.erb' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.yml.erb')}"] }

      it 'loads the config' do
        expect(subject.config.hosts).to eq [
          Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master')
        ]
      end
    end

    context 'with --tf-json' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.minimal.yml')}", "--tf-json=#{fixtures_path('terraform/tf.json')}"] }

      it 'loads the config hosts' do
        expect(subject.config.hosts.map{|h| {address: h.address, role: h.role}}).to eq [
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
        expect(subject.config.api.endpoint).to eq 'api.example.com'
      end
    end
  end
end
