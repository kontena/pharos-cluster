require 'pharos/phases/label_node'

describe Pharos::Phases::LabelNode do
  let(:master) { Pharos::Configuration::Host.new(address: '192.0.2.1') }
  let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.2', labels: { foo: 'bar' } ) }
  let(:subject) { described_class.new(host, master: master) }

  let(:kube) { double(:kube) }

  before(:each) do
    allow(subject).to receive(:kube).and_return(kube)
  end

  describe '#find_node' do
    before(:each) do
      allow(subject).to receive(:sleep)
    end

    it 'finds node via hostname' do
      host.hostname = 'host-01'
      allow(kube).to receive(:get_nodes).and_return([
        Kubeclient::Resource.new({
          metadata: {
            name: host.hostname
          }
        })
      ])
      expect(subject.find_node).not_to be_nil
    end

    it 'returns nil if node not found' do
      host.hostname = 'host-01'
      allow(kube).to receive(:get_nodes).and_return([
        Kubeclient::Resource.new({
          metadata: {
            name: 'host-09'
          }
        })
      ])
      expect(subject.find_node).to be_nil
    end
  end

  describe '#call' do
    let(:node) { double(:kube_node, metadata: double(name: 'test')) }

    before do
      allow(subject).to receive(:find_node).and_return(node)
    end

    context 'without any host labels' do
      let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.2') }

      it 'does nothing' do
        expect(subject).not_to receive(:find_node)

        subject.call
      end
    end

    context 'without kube node' do
      before do
        allow(subject).to receive(:find_node).and_return(nil)
      end

      it 'raises error if node not found' do
        expect{subject.call}.to raise_error(Pharos::Error)
      end
    end

    context 'with labels' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        labels: {foo: 'bar'},
      ) }

      it 'patches node' do
        expect(kube).to receive(:patch_node).with('test',
          metadata: {
            labels: { :foo => 'bar' },
          },
          spec: {
            taints: [ ],
          }
        )

        subject.call
      end
    end

    context 'with taints' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        taints: [
          Pharos::Configuration::Taint.new(key: 'node-role.kubernetes.io/master', effect: 'NoSchedule'),
        ]
      ) }

      it 'patches node' do
        expect(kube).to receive(:patch_node).with('test',
          metadata: {
            labels: { },
          },
          spec: {
            taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ],
          }
        )

        subject.call
      end
    end
  end
end
