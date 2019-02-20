describe Pharos::CommandOptions::LoadConfig do
  let(:arguments) { [] }

  subject do
    Class.new(Pharos::Command) do
      options :load_config

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
  end
end
