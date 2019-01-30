require "pharos/kube"
require "pharos/phases/configure_dns"

describe Pharos::Phases::ConfigureDNS do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config_hosts_count) { 1 }
  let(:config_dns_replicas) { nil }
  let(:config) { Pharos::Config.new(
      hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
      network: {
        dns_replicas: config_dns_replicas,
      },
      addons: {},
      etcd: {}
  ) }
  let(:cpu_arch) { double(:cpu_arch, name: 'amd64') }

  before do
    allow(master).to receive(:cpu_arch).and_return(cpu_arch)
  end

  subject { described_class.new(master, config: config) }

  describe '#call' do
    context "with one host" do
      let(:config_hosts_count) { 1 }

      it "is uses one replica" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 1, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with two hosts" do
      let(:config_hosts_count) { 2 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 2, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with three hosts" do
      let(:config_hosts_count) { 3 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with three hosts and three replicas" do
      let(:config_hosts_count) { 3 }
      let(:config_dns_replicas) { 3 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 3, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with four hosts" do
      let(:config_hosts_count) { 4 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with four hosts and three replicas" do
      let(:config_hosts_count) { 4 }
      let(:config_dns_replicas) { 3 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 3, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with five hosts" do
      let(:config_hosts_count) { 5 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with six hosts and five replicas" do
      let(:config_hosts_count) { 6 }
      let(:config_dns_replicas) { 5 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 5, max_surge: 1, max_unavailable: 2)

        subject.call
      end
    end

    context "with 15 hosts" do
      let(:config_hosts_count) { 15 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 3, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with 40 hosts" do
      let(:config_hosts_count) { 40 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_deployment).with('coredns', replicas: 5, max_surge: 2, max_unavailable: 2)

        subject.call
      end
    end
  end

  describe '#patch_kubedns' do
    let(:kube_client) { instance_double(K8s::Client) }
    let(:kube_api_client) { instance_double(K8s::APIClient) }
    let(:kube_resource_client) { instance_double(K8s::ResourceClient) }

    let(:resource) { K8s::Resource.new(
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        name: 'kube-dns',
        namespace: 'kube-system',
      },
      spec: {
        replicas: 1,
      }
    ) }

    before do
      allow(subject).to receive(:kube_client).and_return(kube_client)
      allow(kube_client).to receive(:api).with('extensions/v1beta1').and_return(kube_api_client)
      allow(kube_api_client).to receive(:resource).with('deployments', namespace: 'kube-system').and_return(kube_resource_client)
    end

    it "updates the resource" do
      expect(kube_resource_client).to receive(:merge_patch).with('kube-dns', Hash) do |_name, h|
        res = K8s::Resource.new(h)

        expect(res.spec.replicas).to eq 1
        expect(res.spec.strategy.rollingUpdate.maxSurge).to eq 0
        expect(res.spec.strategy.rollingUpdate.maxUnavailable).to eq 1
        expect(res.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution).to be_an Array
        expect(res.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions.map{|o| o.to_hash}).to match [
          { key: 'k8s-app', operator: 'In', values: ['kube-dns'] },
        ]
        expect(res.spec.template.spec.containers).to be_nil

        resource
      end

      subject.patch_deployment('kube-dns', replicas: 1, max_surge: 0, max_unavailable: 1)
    end
  end
end
