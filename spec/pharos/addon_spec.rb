require "pharos/addon"

describe Pharos::Addon do
  let(:test_addon) do
    Class.new(Pharos::Addon) do
      self.addon_name = 'test-addon'
      self.addon_location = File.expand_path(File.join(__dir__, '..', 'fixtures', 'stacks', 'multidoc'))

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
  let(:kube_client) { instance_double(K8s::Client) }
  let(:config) { {foo: 'bar'} }

  subject { test_addon.new(config, kube_client: kube_client, cpu_arch: cpu_arch, cluster_config: double(image_repository: 'foo')) }

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

  describe ":validate_configuration hook" do
    context 'arity 1' do
      subject do
        Class.new(Pharos::Addon) do
          validate_configuration do |new_config|
            raise "must be enabled" unless new_config.enabled
          end
        end
      end

      let(:old_cfg) { double(:old) }
      let(:new_cfg) { double(:new, enabled: false) }

      it 'calls the validation with new config' do
        expect(new_cfg).to receive(:enabled).and_return(false)
        expect{subject.apply_validate_configuration(old_cfg, new_cfg)}.to raise_error(RuntimeError, "must be enabled")
      end
    end

    context 'arity 2' do
      subject do
        Class.new(Pharos::Addon) do
          validate_configuration do |old_config, new_config|
            raise "Can not disable" if old_config.enabled && !new_config.enabled
          end
        end
      end

      let(:old_cfg) { double(:old, enabled: true) }
      let(:new_cfg) { double(:new, enabled: false) }
      it 'calls the validation with old config and new config' do
        expect(old_cfg).to receive(:enabled).and_return(true)
        expect(new_cfg).to receive(:enabled).and_return(false)
        expect{subject.apply_validate_configuration(old_cfg, new_cfg)}.to raise_error(RuntimeError, "Can not disable")
      end
    end

    context 'arity 3' do
      subject do
        Class.new(Pharos::Addon) do
          validate_configuration do |key, old_val, new_val|
            raise "#{key} can not change from #{old_val} to #{new_val}"
          end
        end
      end

      let(:old_cfg) { { a: 1, b: { c: 'hello' } } }
      let(:new_cfg) { { a: 1, b: { c: 'hey' } } }
      it 'calls the validation with old config and new config' do
        expect{subject.apply_validate_configuration(old_cfg, new_cfg)}.to raise_error(RuntimeError, "b.c can not change from hello to hey")
      end
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
      Class.new(Pharos::Addon) do
        self.addon_name = 'test-addon-install'

        version "0.2.2"
        license "MIT"

        config {
          attribute :justatest, Pharos::Types::String
        }

        install {
          config.justatest
          apply_resources
        }
      end.new(config, kube_client: kube_client, cpu_arch: cpu_arch, cluster_config: nil)
    end

    let(:kube_stack) { double(:kube_stack) }

    before do
      allow(subject).to receive(:kube_stack).and_return(kube_stack)
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

    it 'loads multiple documents from a single yaml' do
      stack = subject.kube_stack
      expect(stack.resources.first.data.doc).to eq 1
      expect(stack.resources.last.data.doc).to eq 2
    end
  end

  describe "#apply_resources" do
    let(:kube_stack) { double(:kube_stack) }

    before do
      allow(subject).to receive(:kube_stack).and_return(kube_stack)
    end

    it "applies addon resources" do
      expect(kube_stack).to receive(:apply)
      subject.apply_resources
    end
  end

  describe "#post_install_message" do
    it "sets post install message if message given" do
      subject.post_install_message('installed')
      expect(subject.post_install_message).to eq('installed')
    end
  end
end
