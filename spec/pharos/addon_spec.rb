require "pharos/addon"

describe Pharos::Addon do
  let(:test_addon) do
    Class.new(described_class) do
      name "test-addon"
      version "0.2.2"
      license "MIT"

      struct {
        attribute :foo, Pharos::Types::String
        attribute :bar, Pharos::Types::String.default('baz')
      }

      schema {
        required(:foo).filled(:str?)
        optional(:bar).filled(:str?)
      }
    end
  end

  let(:cpu_arch) { double(:cpu_arch) }
  let(:kube_session) { instance_double(Pharos::Kube::Session) }
  let(:config) { {foo: 'bar'} }

  subject { test_addon.new(config, kube: kube_session, cpu_arch: cpu_arch, cluster_config: nil) }

  describe ".name" do
    it "returns configured name" do
      expect(test_addon.name).to eq("test-addon")
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

  describe "#apply_stack" do
    let(:stack) { instance_double(Pharos::Kube::Stack) }

    before do
      allow(kube_session).to receive(:stack).with('test-addon', a_string_ending_with('lib/pharos/addons/test-addon/resources')).and_return(stack)
    end

    it "applies stack with correct parameters" do
      expect(stack).to receive(:apply).with(
        name: subject.class.name,
        version: subject.class.version,
        config: anything,
        arch: anything
      )

      subject.apply_stack
    end
  end
end
