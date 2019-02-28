require 'pharos/phases/label_node'

describe Pharos::Phases::LabelNode do
  let(:master) { Pharos::Configuration::Host.new(address: '192.0.2.1') }
  let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.2', labels: { foo: 'bar' } ) }
  let(:subject) { described_class.new(host) }

  let(:kube_client) { instance_double(K8s::Client) }
  let(:kube_api_v1) { instance_double(K8s::APIClient) }
  let(:kube_nodes) { instance_double(K8s::ResourceClient) }

  before(:each) do
    allow(subject).to receive(:kube_client).and_return(kube_client)
    allow(kube_client).to receive(:api).with('v1').and_return(kube_api_v1)
    allow(kube_api_v1).to receive(:resource).with('nodes').and_return(kube_nodes)
  end

  describe '#find_node' do
    before(:each) do
      allow(subject).to receive(:sleep)
    end

    it 'finds node via hostname' do
      host.hostname = 'host-01'
      allow(kube_nodes).to receive(:get).with('host-01').and_return([
        K8s::Resource.new({
          metadata: {
            name: host.hostname
          }
        })
      ])
      expect(subject.find_node).not_to be_nil
    end

    it 'returns nil if node not found' do
      host.hostname = 'host-01'
      allow(kube_nodes).to receive(:get).with('host-01').and_raise(K8s::Error::NotFound.new('GET', '/asdf', 404, "Not Found", K8s::API::MetaV1::Status.new(metadata: {})))
      expect(subject.find_node).to be_nil
    end
  end

  describe '#call' do
    let(:node) { double(:kube_node, metadata: double(name: 'test')) }

    before do
      allow(subject).to receive(:find_node).and_return(node)
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
        expect(node).to receive(:merge).with(
          metadata: {
            labels: { :foo => 'bar', 'node-address.kontena.io/external-ip' => '192.0.2.2' },
          },
        ).and_return(node)

        expect(kube_nodes).to receive(:update_resource).with(node)

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
        allow(subject).to receive(:patch_labels)
        expect(node).to receive(:merge).with(
          spec: {
            taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ],
          }
        ).and_return(node)

        expect(kube_nodes).to receive(:update_resource).with(node)

        subject.call
      end
    end

    context 'with labels and taints' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        labels: {foo: 'bar'},
        taints: [
          Pharos::Configuration::Taint.new(key: 'node-role.kubernetes.io/master', effect: 'NoSchedule'),
        ]
      ) }

      it 'patches node twice' do
        expect(node).to receive(:merge).with(
          metadata: {
            labels: { :foo => 'bar', 'node-address.kontena.io/external-ip' => '192.0.2.2' },
          },
        ).and_return(node)
        expect(node).to receive(:merge).with(
          spec: {
            taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ],
          }
        ).and_return(node)

        expect(kube_nodes).to receive(:update_resource).with(node).twice

        subject.call
      end
    end
  end
end
