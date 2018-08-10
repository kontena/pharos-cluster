require "pharos/addon"

describe Pharos::Addon do
  let(:test_addon) do
    Pharos.addon 'test-addon' do
      version "0.2.2"
      license "MIT"

      config {
        attribute :foo, Pharos::Types::String
        attribute :bar, Pharos::Types::String.default('baz')
      }

      config_schema {
        required(:foo).filled(:str?)
        optional(:bar).filled(:str?)
      }
    end
  end

  let(:cpu_arch) { double(:cpu_arch) }
  let(:master) { double(:host, api_address: '1.1.1.1') }
  let(:config) { {foo: 'bar'} }

  subject { test_addon.new(config, master: master, cpu_arch: cpu_arch, cluster_config: nil) }

  describe ".addon_name" do
    it "returns configured name" do
      expect(test_addon.addon_name).to eq("test-addon")
    end
  end

  describe ".version" do
    it "returns configured version" do
      expect(test_addon.version).to eq("0.2.2")
    end
  end

  describe ".license" do
    it "returns configured license" do
      expect(test_addon.license).to eq("MIT")
    end
  end

  describe ".validate" do
    it "returns result with error if invalid config" do
      result = described_class.validate({})
      expect(result.success?).to be_falsey
      expect(result.errors[:enabled]).not_to be_nil
    end

    it "returns success on valid config" do
      result = described_class.validate({enabled: true, foo: "bar"})
      expect(result.success?).to be_truthy
    end
  end

  describe ".install" do
    subject do
      Pharos.addon 'test-addon-install' do
        version "0.2.2"
        license "MIT"

        config {
          attribute :justatest, Pharos::Types::String
        }

        install {
          config.justatest
          apply_resources
        }
      end.new(config, master: master, cpu_arch: cpu_arch, cluster_config: nil)
    end

    let(:kube_stack) { double(:kube_stack) }
    let(:kube_client) { double(:kube_client) }

    before do
      allow(subject).to receive(:kube_stack).and_return(kube_stack)
      allow(subject).to receive(:kube_client).and_return(kube_client)
    end

    it 'runs install block on apply' do
      expect(subject.config).to receive(:justatest)
      expect(kube_stack).to receive(:apply).with(kube_client)
      subject.apply
    end
  end

  describe "#kube_stack" do
    it "returns kube stack" do
      stack = subject.kube_stack
      expect(stack).to be_instance_of(Pharos::Kube::Stack)
    end
  end

  describe "#apply_resources" do
    let(:kube_stack) { double(:kube_stack) }
    let(:kube_client) { double(:kube_client) }

    before do
      allow(subject).to receive(:kube_stack).and_return(kube_stack)
      allow(subject).to receive(:kube_client).and_return(kube_client)
    end

    it "applies addon resources" do
      expect(kube_stack).to receive(:apply)
      subject.apply_resources
    end
  end

  describe '#kube_client' do
    it 'returns kube client' do
      client = double(:client)
      allow(Pharos::Kube).to receive(:client).with(master.api_address).and_return(client)
      expect(subject.kube_client).to eq(client)
    end
  end
end
