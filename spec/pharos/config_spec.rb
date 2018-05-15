describe Pharos::Config do
  let(:hosts) { [
    { 'address' => '192.0.2.1', 'role' => 'master' },
  ] }
  let(:data) { {
      'hosts' => hosts,
  } }

  subject { described_class.load(data) }

  describe '#addons' do
    it 'returns empty addons by default' do
      expect(subject.addons).to eq({})
    end
  end

  describe '#kubelet' do
    it 'disables the readonly port by deault' do
      expect(subject.kubelet.read_only_port).to eq(false)
    end
  end
end
