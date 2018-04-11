require "pharos/addons/ingress_nginx"

describe Pharos::Addons::IngressNginx do

  let(:cpu_arch) { double(:cpu_arch ) }

  let(:host) { double(:host, address: '1.1.1.1', cpu_arch: cpu_arch) }

  let(:subject) do
    test_addon.new(host, {foo: 'bar'})
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
    it "returns configured name" do
      expect(cpu_arch).not_to receive(:name)
      subject = described_class.new(host, {default_backend: {image: 'some_image'}})
      expect(subject.image_name).to eq("some_image")
    end

    it "returns default for arm64" do
      expect(cpu_arch).to receive(:name).and_return('arm64')
      subject = described_class.new(host, {})
      expect(subject.image_name).to eq(Pharos::Addons::IngressNginx::DEFAULT_BACKEND_ARM64_IMAGE)
    end

    it "returns configured name" do
      expect(cpu_arch).to receive(:name).and_return('amd64')
      subject = described_class.new(host, {})
      expect(subject.image_name).to eq(Pharos::Addons::IngressNginx::DEFAULT_BACKEND_IMAGE)
    end
  end
end