require "pharos/phases/configure_calico"

describe Pharos::Phases::ConfigureCalico do
  let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.1') }
  let(:config_network) { { }}
  let(:config) { Pharos::Config.new(
      hosts: [host],
      network: config_network,
      addons: {},
      etcd: {},
      kubelet: {read_only_port: false}
  ) }

  subject { described_class.new(host, config: config, master: host) }

  describe '#get_ippool' do
    let(:kube_client) { instance_double(K8s::Client) }
    let(:kube_api_client) { instance_double(K8s::APIClient) }
    let(:kube_resource_client) { instance_double(K8s::ResourceClient) }

    let(:resource) { K8s::Resource.new(
      apiVersion: 'crd.projectcalico.org/v1',
      kind: 'IPPool',
      metadata: {
        name: 'default-ipv4-ippool',
      },
    ) }

    before do
      allow(subject).to receive(:kube_client).and_return(kube_client)
      allow(kube_client).to receive(:api).with('crd.projectcalico.org/v1').and_return(kube_api_client)
      allow(kube_api_client).to receive(:resource).with('ippools').and_return(kube_resource_client)
    end

    it 'returns kube resource' do
      expect(kube_resource_client).to receive(:get).with('default-ipv4-ippool').and_return(resource)

      expect(subject.get_ippool('default-ipv4-ippool')).to eq resource
    end

    it 'returns nil on 404' do
      expect(kube_resource_client).to receive(:get).with('default-ipv4-ippool').and_raise(K8s::Error::NotFound.new('GET', '/asdf', 404, "Not Found", K8s::API::MetaV1::Status.new(metadata: {})))

      expect(subject.get_ippool('default-ipv4-ippool')).to be nil
    end
  end

  describe '#validate_ippool' do
    let(:ippool) { }

    before do
      allow(subject).to receive(:get_ippool).with('default-ipv4-ippool').and_return(ippool)
    end

    context 'without any ippool' do
      let(:ippool) { nil }

      it "does not raise" do
        expect{subject.validate_ippool}.to_not raise_error
      end
    end

    context 'with a matching ippool' do
      let(:ippool) { double(spec: double(cidr: '10.32.0.0/12')) }

      it "does not raise" do
        expect{subject.validate_ippool}.to_not raise_error
      end
    end

    context 'with a mismatching ippool' do
      let(:ippool) { double(spec: double(cidr: '10.128.0.0/12')) }

      it "raises" do
        expect{subject.validate_ippool}.to raise_error(/cluster.yml network.pod_network_cidr has been changed/)
      end
    end
  end
end
