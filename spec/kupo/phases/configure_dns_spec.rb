require "kupo/config"
require "kupo/phases/configure_dns"

describe Kupo::Phases::ConfigureDNS do
  let(:master) { Kupo::Configuration::Host.new(address: 'test') }
  let(:config_hosts_count) { 1 }
  let(:config_dns_replicas) { nil }
  let(:config) { Kupo::Config.new(
      hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
      network: {
        dns_replicas: config_dns_replicas,
      },
      addons: {},
  ) }
  subject { described_class.new(master, config) }

  describe '#call' do
    context "with one host" do
      let(:config_hosts_count) { 1 }

      it "is uses one replica" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 1, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with two hosts" do
      let(:config_hosts_count) { 2 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 2, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with three hosts" do
      let(:config_hosts_count) { 3 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with three hosts and three replicas" do
      let(:config_hosts_count) { 3 }
      let(:config_dns_replicas) { 3 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 3, max_surge: 0, max_unavailable: 1)

        subject.call
      end
    end

    context "with four hosts" do
      let(:config_hosts_count) { 4 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with four hosts and three replicas" do
      let(:config_hosts_count) { 4 }
      let(:config_dns_replicas) { 3 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 3, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with five hosts" do
      let(:config_hosts_count) { 5 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 2, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with six hosts and five replicas" do
      let(:config_hosts_count) { 6 }
      let(:config_dns_replicas) { 5 }

      it "is uses two replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 5, max_surge: 1, max_unavailable: 2)

        subject.call
      end
    end

    context "with 15 hosts" do
      let(:config_hosts_count) { 15 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 3, max_surge: 1, max_unavailable: 1)

        subject.call
      end
    end

    context "with 40 hosts" do
      let(:config_hosts_count) { 40 }

      it "is uses three replicas" do
        expect(subject).to receive(:patch_kubedns).with(replicas: 5, max_surge: 2, max_unavailable: 2)

        subject.call
      end
    end
  end

  describe '#patch_kubedns' do
    it "updates the resource" do
      expect(Kupo::Kube).to receive(:update_resource).with('test', Kubeclient::Resource) do |addr, resource|
        expect(resource.apiVersion).to eq 'extensions/v1beta1'
        expect(resource.kind).to eq 'Deployment'
        expect(resource.metadata.name).to eq 'kube-dns'
        expect(resource.metadata.namespace).to eq 'kube-system'
        expect(resource.spec.replicas).to eq 1
        expect(resource.spec.strategy.rollingUpdate.maxSurge).to eq 0
        expect(resource.spec.strategy.rollingUpdate.maxUnavailable).to eq 1
        expect(resource.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution).to be_an Array
      end

      subject.call
    end
  end
end
