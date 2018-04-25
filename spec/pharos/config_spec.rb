describe Pharos::Config do
  describe '#addons' do
    it 'returns empty addons by default' do
      expect(subject.addons).to eq({})
    end
  end
end
