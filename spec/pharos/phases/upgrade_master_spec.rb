require "pharos/phases/upgrade_master"

describe Pharos::Phases::UpgradeMaster do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config) { Pharos::Config.new(
      hosts: (1..2).map { |i| Pharos::Configuration::Host.new() },
      network: {},
      addons: {},
      etcd: {}
  ) }
  let(:cpu_arch) { double(:cpu_arch, name: 'amd64') }

  before do
    allow(master).to receive(:cpu_arch).and_return(cpu_arch)
  end

  subject { described_class.new(master, config: config) }

  describe '#create_dns_patch_thread' do
    let(:kube_client) { instance_double(K8s::Client) }
    let(:kube_api_client) { instance_double(K8s::APIClient) }
    let(:kube_resource_client) { instance_double(K8s::ResourceClient) }

    before do
      allow(subject).to receive(:kube_client).and_return(kube_client)
      allow(kube_client).to receive(:api).with('extensions/v1beta1').and_return(kube_api_client)
      allow(kube_api_client).to receive(:resource).with('deployments', namespace: 'kube-system').and_return(kube_resource_client)
    end

    it 'patches coredns deployment' do
      expect(kube_resource_client).to receive(:merge_patch) do |name, patch|
        res = K8s::Resource.new(patch)
        expect(res.spec.template.spec.containers[0].image).to include("coredns-#{cpu_arch.name}")
      end

      thread = subject.create_dns_patch_thread(0)
      thread.join
    end
  end
end
