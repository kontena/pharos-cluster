require 'kupo/config'

describe Kupo::Configuration::CpuArch do

  let(:subject) do
    described_class.new(
      id: 'amd64'
    )
  end

  describe '#supported?' do
    it 'returns true when valid id and version' do
      expect(subject.supported?).to be_truthy
    end

    it 'returns false if invalid version' do
      allow(subject).to receive(:id).and_return('armv7')
      expect(subject.supported?).to be_falsey
    end
  end
end