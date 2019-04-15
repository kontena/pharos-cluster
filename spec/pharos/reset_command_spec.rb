describe Pharos::ResetCommand do
  subject { described_class.new('') }

  let(:hosts) do
    [
      { address: '10.0.0.1', role: 'master' },
      { address: '10.0.0.2', role: 'master' },
      { address: '10.0.0.3', role: 'worker' }
    ]
  end

  let(:data) { { hosts: hosts } }
  let(:config) { Pharos::Config.new(data) }

  before do
    allow(subject).to receive(:load_config).and_return(config)
    allow(subject).to receive(:config_yaml).and_return(double(dirname: __dir__))
    allow(subject).to receive_message_chain("cluster_manager.disconnect")
    allow($stdin).to receive(:tty?).and_return(true)
  end

  describe '#execute' do
    context 'confirmations' do
      context 'reset all' do
        it 'prompts and resets all' do
          expect(subject.prompt).to receive(:yes?).with(/Do you really want to reset all/, default: false).and_return(true)
          expect(subject).to receive_message_chain("cluster_manager.apply_reset_hosts").with(config.hosts)
          subject.run([])
        end
      end

      context 'resetting masters' do
        context 'would remove all masters' do
          it 'aborts with error' do
            expect{subject.run(%w(-r master))}.to raise_exception(Clamp::ExecutionError, /no master hosts left/)
          end
        end

        context 'would remove some of the masters' do
          it 'prompts' do
            expect(subject.prompt).to receive(:yes?).with(/Do you really want/, default: false).and_return(false)
            expect{subject.run(%w(-r master --first))}.to raise_error(SystemExit)
          end
        end
      end

      context 'resetting single host' do
        context 'with --yes' do
          it 'does not prompt' do
            expect(subject).to receive_message_chain("cluster_manager.apply_reset_hosts").with([config.hosts.last])
            subject.run(%w(--yes -a 10.0.0.3))
          end
        end

        context 'without --yes' do
          it 'prompts' do
            expect(subject.prompt).to receive(:yes?).with(/Do you really want/, default: false).and_return(false)
            expect{subject.run(%w(-a 10.0.0.3))}.to raise_error(SystemExit)
          end
        end
      end
    end
  end
end
