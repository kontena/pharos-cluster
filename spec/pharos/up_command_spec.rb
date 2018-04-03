describe Pharos::UpCommand do
  subject { described_class.new('') }

  context 'configuration file' do
    before do
      allow(subject).to receive(:configure).and_return(true)
    end

    context 'default from cluster.yml in current directory' do
      it 'reads the cluster.yml from current directory' do
        allow(File).to receive(:realpath).with('cluster.yml').and_return('cluster.yml')
        expect(File).to receive(:read).with('cluster.yml').and_return('config')
        expect(subject).to receive(:load_config).with('config').and_return(true)
        subject.run([])
      end
    end

    context 'using --config' do
      it 'reads the file from the specified location' do
        allow(File).to receive(:realpath).with('/tmp/test.yml').and_return('test.yml')
        expect(File).to receive(:read).with('test.yml').and_return('config')
        expect(subject).to receive(:load_config).with('config').and_return(true)
        subject.run(['--config', '/tmp/test.yml'])
      end
    end

    context 'from stdin' do
      it 'reads the file from stdin' do
        expect(File).not_to receive(:realpath)
        expect(subject).to receive(:load_config).with('config from stdin').and_return(true)
        old_stdin = $stdin
        begin
          $stdin = StringIO.new('config from stdin')
          subject.run([])
        ensure
          $stdin = old_stdin
        end
      end
    end
  end
end
