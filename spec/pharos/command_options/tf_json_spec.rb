describe Pharos::CommandOptions::TfJson do
  let(:arguments) { [] }

  subject do
    Class.new(Pharos::Command) do
      options :load_config, :tf_json

      def config
        @config ||= load_config
      end
    end.new('').tap do |subject|
      subject.parse(arguments)
    end
  end

  describe '#load_config' do
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
