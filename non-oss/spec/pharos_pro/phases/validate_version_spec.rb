require 'pharos/phases/validate_version'
require 'pharos_pro/phases/validate_version'

describe Pharos::Phases::ValidateVersion do
  let(:host) { Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master') }
  let(:network_config) { {} }
  let(:config) { Pharos::Config.new(hosts: [host]) }
  subject { described_class.new(host, config: config) }

  describe '#validate_version' do
    it 'allows re-up for stable releases' do
      stub_const('Pharos::VERSION', '1.3.3')
      expect{subject.validate_version('1.3.3')}.not_to raise_error
    end

    it 'allows re-up for development releases' do
      stub_const('Pharos::VERSION', '2.0.0-alpha.1')
      expect{subject.validate_version('2.0.0-alpha.1')}.not_to raise_error
    end

    it 'allows upgrade from patch-release to another' do
      stub_const('Pharos::VERSION', '2.0.1')
      expect{subject.validate_version('2.0.0')}.not_to raise_error
    end

    it 'allows upgrade from patch-release to development patch-release' do
      stub_const('Pharos::VERSION', '2.0.1-alpha.1')
      expect{subject.validate_version('2.0.0')}.not_to raise_error
    end

    it 'does not allow downgrade on development releases' do
      stub_const('Pharos::VERSION', '2.0.0-alpha.1')
      expect{subject.validate_version('2.0.0-alpha.2')}.to raise_error(RuntimeError, "Downgrade not supported")
    end

    it 'does not allow downgrade on stable releases' do
      stub_const('Pharos::VERSION', '1.3.3')
      expect{subject.validate_version('2.0.0')}.to raise_error(RuntimeError, "Downgrade not supported")
    end

    it 'does not allow downgrade from stable to prerelease' do
      stub_const('Pharos::VERSION', '2.0.0-alpha.1')
      expect{subject.validate_version('2.0.0')}.to raise_error(RuntimeError, "Downgrade not supported")
    end

    it 'does not allow downgrade from prerelease to stable' do
      stub_const('Pharos::VERSION', '2.0.0')
      expect{subject.validate_version('2.0.1-alpha.1')}.to raise_error(RuntimeError, "Downgrade not supported")
    end

    it 'allows upgrade to point-release' do
      stub_const('Pharos::VERSION', '2.1.0')
      expect{subject.validate_version('2.0.0')}.not_to raise_error
    end
  end
end

