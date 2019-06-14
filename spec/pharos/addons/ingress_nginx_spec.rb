require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./addons/ingress-nginx/addon.rb"

describe Pharos::AddonManager.addons['ingress-nginx'] do
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
    described_class.new(config, enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client })
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
      let(:config) { {default_backend: {'image' => 'some_image'}} }

      it "returns configured name" do
        expect(cpu_arch).not_to receive(:name)
        expect(subject.config.default_backend['image']).to eq("some_image")
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
