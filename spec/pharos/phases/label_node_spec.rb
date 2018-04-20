require 'pharos/phases/label_node'

describe Pharos::Phases::LabelNode do
  let(:kube_session) { instance_double(Pharos::Kube::Session) }
  let(:worker) { Pharos::Configuration::Host.new(address: '2.2.2.2', labels: {foo: 'bar'}) }
  let(:subject) { described_class.new(worker, kube: kube_session) }

  let(:kube_client) { double(:kube_client) }

  before do
    allow(kube_session).to receive(:client).with(no_args).and_return(kube_client)
  end

  describe '#find_node' do
    before(:each) do
      allow(subject).to receive(:sleep)
    end

    it 'finds node via address' do
      expect(kube_client).to receive(:get_nodes).and_return([
        Kubeclient::Resource.new({
          status: {
            addresses: [
              { type: 'InternalIP', address: worker.address }
            ]
          }
        })
      ])
      expect(subject.find_node).not_to be_nil
    end

    it 'returns nil if node not found' do
      expect(kube_client).to receive(:get_nodes).at_least(:once).and_return([
        Kubeclient::Resource.new({
          status: {
            addresses: [
              { type: 'InternalIP', address: 'a.b.c.d' }
            ]
          }
        })
      ])
      expect(subject.find_node).to be_nil
    end
  end

  describe '#call' do
    it 'does nothing if node does not have labels' do
      allow(worker).to receive(:labels).and_return(nil)
      expect(subject).not_to receive(:find_node)
      subject.call
    end

    it 'patches node if node has labels and it exist in kube api' do
      node = double(:node)
      allow(subject).to receive(:find_node).and_return(node)
      expect(subject).to receive(:patch_node).with(node)
      subject.call
    end

    it 'raises error if node not found' do
      allow(subject).to receive(:find_node).and_return(nil)
      expect {
        subject.call
      }.to raise_error(Pharos::Error)
    end
  end
end
