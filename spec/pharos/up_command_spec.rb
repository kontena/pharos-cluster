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
      allow(subject).to receive(:confirm_yes!).and_return(true)
      expect(subject).not_to receive(:prompt)
      subject.prompt_continue(config)
    end

    it 'shows config' do
      allow(subject).to receive(:confirm_yes!).and_return(true)
      expect(subject).to receive(:color?).and_return(true).at_least(1).times
      expect(config).to receive(:to_yaml).and_return('---')
      subject.prompt_continue(config)
    end

    it 'shows config without color' do
      allow(subject).to receive(:confirm_yes!).and_return(true)
      expect(subject).to receive(:color?).and_return(false).at_least(1).times
      expect(config).to receive(:to_yaml).and_return('---')
      subject.prompt_continue(config)
    end
  end
end
