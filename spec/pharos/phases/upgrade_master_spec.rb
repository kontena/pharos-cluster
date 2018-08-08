require "pharos/phases/upgrade_master"

describe Pharos::Phases::UpgradeMaster do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config) { Pharos::Config.new(
      hosts: (1..2).map { |i| Pharos::Configuration::Host.new() },
      network: {},
      addons: {},
      etcd: {}
  ) }
  let(:kube_session) { double(:kube_session) }
  let(:resource_client) { double(:resource_client) }
  let(:cpu_arch) { double(:cpu_arch, name: 'amd64') }

  subject { described_class.new(master, config: config) }

  describe '#create_dns_patch_thread' do
    it 'patches coredns deployment' do
      allow(master).to receive(:cpu_arch).and_return(cpu_arch)
      allow(subject).to receive(:kube_session).and_return(kube_session)
      allow(kube_session).to receive(:resource_client).and_return(resource_client)
      expect(resource_client).to receive(:patch_deployment) do |name, patch, namespace|
        res = Kubeclient::Resource.new(patch)
        expect(res.spec.template.spec.containers[0].image).to include("coredns-#{cpu_arch.name}")
      end

      thread = subject.create_dns_patch_thread(0)
      thread.join
    end
  end
end