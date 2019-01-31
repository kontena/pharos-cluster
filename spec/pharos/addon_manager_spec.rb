require 'tmpdir'
require 'fileutils'

describe Pharos::AddonManager do
  describe 'load addons' do
    let(:tmpdir_1) { Dir.mktmpdir }
    let(:tmpdir_2) { Dir.mktmpdir }

    before do
      FileUtils.touch(File.join(tmpdir_2, 'addon.rb'))
      FileUtils.ln_s(tmpdir_2, File.join(tmpdir_1, 'linked-addon'))
    end

    after do
      FileUtils.rm_rf(tmpdir_1)
      FileUtils.rm_rf(tmpdir_2)
    end

    it 'loads files from symlinked subdirectories' do
      expect(described_class).to receive(:require).with(File.join(tmpdir_1, 'linked-addon', 'addon.rb'))
      described_class.load_addons(tmpdir_1)
    end
  end

  describe '#validate' do
    let(:hosts) { [{ address: '192.168.0.0', role: 'master' }] }
    let(:enabled_addon) do
      Class.new(Pharos::Addon) do
        version '1'
        self.addon_name = 'enabled_addon'

        config_schema do
          optional(:top).schema do
            required(:nested).filled(:str?)
          end
        end
      end
    end

    before do
      allow(subject).to receive(:addon_classes).and_return([enabled_addon])
    end

    subject { described_class.new(config, {}) }

    context 'success' do
      let(:config) do
        Pharos::Config.new(
          hosts: hosts,
          addons: {
            'enabled_addon' => {
              enabled: true,
              top: {
                nested: 'test'
              }
            }
          }
        )
      end

      it 'passes' do
        expect(enabled_addon).to receive(:validate).and_call_original
        expect(subject.validate).to be_truthy
      end
    end

    context 'failure' do
      let(:config) do
        Pharos::Config.new(
          hosts: hosts,
          addons: {
            'enabled_addon' => {
              enabled: true,
              top: {
                nested: 123
              }
            }
          }
        )
      end

      it 'fails' do
        expect{subject.validate}.to raise_error do |error|
          expect(error).to be_a Pharos::AddonManager::InvalidConfig
          message = YAML.safe_load(error.message)
          expect(message).to match hash_including(
            "enabled_addon" => {
              "top" => {
                "nested" => [
                  "must be a string"
                ]
              }
            }
          )
        end
      end
    end
  end
end
