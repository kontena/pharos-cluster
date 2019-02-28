describe Pharos::Command do
  before do
    allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
  end

  subject do
    Class.new(described_class) do
      def execute
        puts "hello"
      end
    end
  end

  it 'can display help' do
    expect{subject.run('pharos', %w(--help))}.to output(/Usage:.*Options:/m).to_stdout
  end

  it 'runs command' do
    expect{subject.run('pharos', [])}.to output(/hello/m).to_stdout
  end

  context 'error messages' do
    context 'exceptions' do
      subject do
        Class.new(described_class) do
          def execute
            raise "error"
          end
        end
      end

      it 'displays error message instead of backtrace' do
        expect{subject.run('pharos', [])}.to exit_with_error.and output(
          "ERROR: RuntimeError : error\n"
        ).to_stderr
      end
    end

    context 'signal_error' do
      subject do
        Class.new(described_class) do
          def execute
            signal_error "test"
          end
        end
      end

      it 'displays error message' do
        expect{subject.run('pharos', [])}.to exit_with_error.and output(
          "ERROR: test\n"
        ).to_stderr
      end
    end

    context 'signal_usage_error' do
      subject do
        Class.new(described_class) do
          def execute
            signal_usage_error "test"
          end
        end
      end

      it 'displays error message and --help hint for unrecognised options' do
        expect{subject.run('pharos', %w(--test))}.to exit_with_error.and output(
          "ERROR: Unrecognised option '--test'\n\nSee: 'pharos --help'\n"
        ).to_stderr
      end

      it 'displays error message and --help hint' do
        expect{subject.run('pharos', [])}.to exit_with_error.and output(
          "ERROR: test\n\nSee: 'pharos --help'\n"
        ).to_stderr
      end
    end
  end

  context 'config error' do
    subject do
      Class.new(described_class) do
        def execute
          Pharos::Config.load({})
        end
      end
    end

    it 'displays error message instead of backtrace' do
      expect{subject.run('pharos', [])}.to exit_with_error.status(11).and output(
        "==> Invalid configuration:\n---\n:hosts:\n- must be filled\n- size cannot be less than 1\n"
      ).to_stderr
    end
  end
end
