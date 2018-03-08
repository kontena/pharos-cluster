require 'kupo/config'

describe Kupo::Configuration::OsRelease do

  let(:subject) do
    described_class.new(
      id: 'ubuntu',
      version: '16.04',
      name: 'Ubuntu 16.04.2 LTS'
    )
  end

  describe '#supported?' do
    it 'returns true when valid id and version' do
      expect(subject.supported?).to be_truthy
    end

    it 'returns false if invalid version' do
      allow(subject).to receive(:version).and_return('18.04')
      expect(subject.supported?).to be_falsey
    end

    it 'returns false if invalid id' do
      allow(subject).to receive(:id).and_return('debian')
      expect(subject.supported?).to be_falsey
    end
  end
end