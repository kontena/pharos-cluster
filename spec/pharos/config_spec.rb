describe Pharos::Config do
  describe '#addons' do
    it 'returns empty addons by default' do
      expect(subject.addons).to eq({})
    end
  end

  describe '#kubelet' do
    let(:subject) do
      described_class.new({kubelet: {}})
    end
    it 'returns default kubelet config' do
      expect(subject.kubelet.read_only_port).to eq(false)
    end
  end
end
