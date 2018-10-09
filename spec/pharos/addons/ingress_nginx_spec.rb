require 'pharos/addon'
require "./addons/ingress-nginx/addon"

describe Pharos::Addons::IngressNginx do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { { foo: 'bar'} }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject do
    described_class.new(config, enabled: true, kube_client: kube_client, cpu_arch: cpu_arch, cluster_config: cluster_config)
  end

  describe "#validate" do
    it "validates default_backend as optional" do
      result = described_class.validate({enabled: true})
      expect(result.success?).to be_truthy

    end

    it "wants image in default_backend to be a string" do
       result = described_class.validate({enabled: true, default_backend: {image: 12345}})
       expect(result.success?).to be_falsey
       expect(result.errors.dig(:default_backend, :image)).not_to be_nil
    end
  end


  describe "#image_name" do
    context "with a configured image" do
      let(:config) { {default_backend: {image: 'some_image'}} }

      it "returns configured name" do
        expect(cpu_arch).not_to receive(:name)
        expect(subject.image_name).to eq("some_image")
      end
    end

    context "for cpu_arch=arm64" do
      let(:cpu_arch) { double(:cpu_arch, name: 'arm64' ) }

      it "returns default for arm64" do
        expect(subject.image_name).to eq('docker.io/kontena/pharos-default-backend-arm64:0.0.3')
      end
    end

    context "for cpu_arch=amd64" do
      let(:cpu_arch) { double(:cpu_arch, name: 'amd64' ) }

      it "returns default" do
        expect(subject.image_name).to eq('docker.io/kontena/pharos-default-backend-amd64:0.0.3')
      end
    end
  end

  describe '#default_backend_replicas' do
    it 'returns 1 replica for no workers' do
      allow(subject).to receive(:worker_node_count).and_return(0)
      expect(subject.default_backend_replicas).to eq(1)
    end

    it 'returns 1 replica for single worker' do
      allow(subject).to receive(:worker_node_count).and_return(1)
      expect(subject.default_backend_replicas).to eq(1)
    end

    it 'returns 2 replicas for 3 workers' do
      allow(subject).to receive(:worker_node_count).and_return(3)
      expect(subject.default_backend_replicas).to eq(2)
    end

    it 'returns 7 replicas with 70 workers' do
      allow(subject).to receive(:worker_node_count).and_return(70)
      expect(subject.default_backend_replicas).to eq(7)
    end
  end
end
