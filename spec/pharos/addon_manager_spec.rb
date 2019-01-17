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
end
