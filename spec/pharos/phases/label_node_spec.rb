require 'pharos/phases/label_node'

describe Pharos::Phases::LabelNode do
  let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.2', labels: { foo: 'bar' } ) }
  let(:config) { Pharos::Config.new(hosts: [host]) }

  let(:subject) { described_class.new('localhost', config: config) }

  let(:kube_client) { instance_double(K8s::Client) }
  let(:kube_api_v1) { instance_double(K8s::APIClient) }
  let(:kube_nodes) { instance_double(K8s::ResourceClient) }

  before(:each) do
    allow(subject).to receive(:kube_client).and_return(kube_client)
    allow(kube_client).to receive(:api).with('v1').and_return(kube_api_v1)
    allow(kube_api_v1).to receive(:resource).with('nodes').and_return(kube_nodes)
  end

  describe '#find_node' do
    it 'finds node via hostname' do
      host.hostname = 'host-01'
      expect(kube_nodes).to receive(:get).with('host-01').and_return(:node)
      expect(subject.find_node(host)).to eq :node
    end
  end

  describe '#host_patch_data' do
    let(:taint) { Pharos::Configuration::Taint.new(key: 'node-role.kubernetes.io/master', effect: 'NoSchedule') }

    it 'contains labels if host has labels' do
      expect(subject.host_patch_data(Pharos::Configuration::Host.new(address: '10.0.0.1', labels: { 'foo' => 'bar' }))).to match hash_including(
        metadata: { labels: { "foo" => "bar", "node-address.kontena.io/external-ip" => "10.0.0.1" } },
      )
    end

    it 'contains taints if host has taints' do
      expect(subject.host_patch_data(Pharos::Configuration::Host.new(taints: [taint]))).to match hash_including(
        spec: { taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ] }
      )
    end

    it 'contains both if host has both' do
      expect(subject.host_patch_data(Pharos::Configuration::Host.new(address: '10.0.0.1', labels: { 'foo'=> 'bar' }, taints: [taint]))).to match hash_including(
        metadata: { labels: { "foo" => "bar", "node-address.kontena.io/external-ip" => "10.0.0.1" } },
        spec: { taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ] }
      )
    end

    context 'with labels' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        private_address: '10.0.0.1',
        role: 'master',
        labels: {foo: 'bar'},
      ) }

      it 'patches node' do
        expect(node).to receive(:merge).with(
          metadata: {
            labels: { :foo => 'bar', 'node-address.kontena.io/external-ip' => '192.0.2.2', 'node-address.kontena.io/internal-ip' => '10.0.0.1', 'node-role.kubernetes.io/master' => '' },
          },
        ).and_return(node)
      end
    end
  end

  describe '#call' do
    let(:node) { double(:kube_node, metadata: double(name: 'test')) }

    before do
      allow(subject).to receive(:find_node).with(host).and_return(node)
    end

    context 'with labels' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        labels: { "foo" => "bar" },
      ) }

      it 'patches node' do
        expect(node).to receive(:merge).with(
          metadata: { labels: { "foo" => "bar", "node-address.kontena.io/external-ip" => "192.0.2.2" } },
        ).and_return(node)

        expect(kube_nodes).to receive(:update_resource).with(node)

        subject.call
      end
    end

    context 'with labels and taints' do
      let(:host) { Pharos::Configuration::Host.new(
        address: '192.0.2.2',
        private_address: '10.0.0.1',
        labels: {foo: 'bar'},
        role: 'master',
        taints: [
          Pharos::Configuration::Taint.new(key: 'node-role.kubernetes.io/master', effect: 'NoSchedule'),
        ]
      ) }

      it 'patches node twice' do
        expect(node).to receive(:merge).with(
          metadata: {
            labels: { :foo => 'bar', 'node-address.kontena.io/external-ip' => '192.0.2.2', 'node-address.kontena.io/internal-ip' => '10.0.0.1', 'node-role.kubernetes.io/master' => '' },
          },
        ).and_return(node)
        expect(node).to receive(:merge).with(
          metadata: { labels: { "foo" => "bar", "node-address.kontena.io/external-ip" => "192.0.2.2" } },
          spec: { taints: [ { key: 'node-role.kubernetes.io/master', effect: 'NoSchedule' } ] }
        ).and_return(node)

        expect(kube_nodes).to receive(:update_resource).with(node)

        subject.call
      end
    end
  end
end
