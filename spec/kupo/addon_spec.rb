require "kupo/addon"

describe Kupo::Addon do
  let(:test_addon) do
    Class.new(described_class) do
      name "test-addon"
      version "0.2.2"
      license "MIT"

      struct {
        attribute :foo, Kupo::Types::String
        attribute :bar, Kupo::Types::String.default('baz')
      }

      schema {
        required(:foo).filled(:str?)
        optional(:bar).filled(:str?)
      }
    end
  end

  let(:host) { double(:host, address: '1.1.1.1', cpu_arch: double(:cpu_arch )) }

  let(:subject) do
    test_addon.new(host, {foo: 'bar'})
  end

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
    it "applies stack with correct parameters" do
      expect(Kupo::Kube).to receive(:apply_stack).with(
        host.address, subject.class.name, {
          name: subject.class.name, version: subject.class.version,
          config: anything, arch: anything
        }
      )
      subject.apply_stack
    end
  end
end