describe Pharos::CommandOptions::LoadConfig do
  let(:arguments) { [] }

  subject do
    Class.new(Pharos::Command) do
      options :load_config

      option '--master-only', :flag, 'master only'

      def config
        @config ||= load_config(master_only: master_only?)
      end
    end.new('').tap do |subject|
      subject.parse(arguments)
    end
  end

  describe '#load_config' do
    it 'loads the cluster.yml from the current directory' do
      Dir.chdir fixtures_path do
        expect(subject.config.hosts.size).to eq 1
        expect(subject.config.hosts.first.to_h).to match hash_including(address: '192.0.2.1', role: 'master')
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

      expect(subject.config.hosts.size).to eq 1
      expect(subject.config.hosts.first.to_h).to match hash_including(address: '192.0.2.1', role: 'master')
    end

    context 'with --config=.../cluster.yml' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.yml')}"] }

      it 'loads the config' do
        expect(subject.config.hosts.size).to eq 1
        expect(subject.config.hosts.first.to_h).to match hash_including(address: '192.0.2.1', role: 'master')
      end
    end

    context 'with --config=.../cluster.yml.erb' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.yml.erb')}"] }

      it 'loads the config' do
        expect(subject.config.hosts.size).to eq 1
        expect(subject.config.hosts.first.to_h).to match hash_including(address: '192.0.2.1', role: 'master')
      end
    end

    context 'master_only: true' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.master_and_worker.yml')}", "--master-only"] }

      it 'only loads master hosts' do
        expect(subject.config.hosts.size).to eq 1
        expect(subject.config.hosts.first.master?).to be_truthy
      end
    end

    context 'master_only: false' do
      let(:arguments) { ["--config=#{fixtures_path('cluster.master_and_worker.yml')}"] }

      it 'only loads all hosts' do
        expect(subject.config.hosts.size).to eq 2
        expect(subject.config.hosts.first.master?).to be_truthy
        expect(subject.config.hosts.last.worker?).to be_truthy
      end
    end
  end

  describe '#cluster_manager' do
    let(:c_context) { Pharos::ClusterContext.new(config: subject.config) }
    let(:cm_instance) { instance_double(Pharos::ClusterManager, context: c_context) }
    let(:arguments) { ["--config=#{fixtures_path('cluster.yml')}"] }

    it 'instantiates a loaded cluster manager based on the loaded configuration' do
      expect(Pharos::ClusterContext).to receive(:new).with(config: subject.config).and_return(c_context)
      expect(Pharos::ClusterManager).to receive(:new).with(c_context).and_return(cm_instance)
      expect(cm_instance).to receive(:load)
      expect(cm_instance).to receive(:validate)
      subject.cluster_manager
    end

    context 'extra context args' do
      let(:c_context) { Pharos::ClusterContext.new(config: subject.config, force: true) }

      it 'instantiates a loaded cluster manager based on the loaded configuration and extra context' do
        expect(Pharos::ClusterContext).to receive(:new).with(config: subject.config, force: true).and_return(c_context)
        expect(Pharos::ClusterManager).to receive(:new).with(c_context).and_return(cm_instance)
        expect(cm_instance).to receive(:load)
        expect(cm_instance).to receive(:validate)
        expect(subject.cluster_manager(force: true).context.force).to be_truthy
      end
    end
  end
end
