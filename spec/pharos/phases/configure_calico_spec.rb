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

  let(:kube_session) { instance_double(Pharos::Kube::Session) }

  subject { described_class.new(host, config: config, master: host) }

  before do
    allow(subject).to receive(:kube_session).and_return(kube_session)
  end

  describe '#get_ippool' do
    let(:kube_client) { instance_double(Pharos::Kube::Client) }
    let(:ippool) { Kubeclient::Resource.new }

    before do
      expect(kube_session).to receive(:resource_client).with('crd.projectcalico.org/v1').and_return(kube_client)
    end

    it 'returns kube resource' do
      expect(kube_client).to receive(:get_entity).with('ippools', 'test').and_return(ippool)

      expect(subject.get_ippool('test')).to eq ippool
    end

    it 'returns nil on 404' do
      expect(kube_client).to receive(:get_entity).with('ippools', 'test').and_raise(Kubeclient::ResourceNotFoundError.new(404, "Not Found", double()))

      expect(subject.get_ippool('test')).to be nil
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
