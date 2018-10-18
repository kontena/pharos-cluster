require "pharos/phases/upgrade_master"

describe Pharos::Phases::UpgradeMaster do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config) { Pharos::Config.new(
      hosts: (1..2).map { |i| Pharos::Configuration::Host.new() },
      network: {},
      addons: {},
      etcd: {}
  ) }
  let(:cpu_arch) { double(:cpu_arch, name: 'amd64') }

  before do
    allow(master).to receive(:cpu_arch).and_return(cpu_arch)
  end

  subject { described_class.new(master, config: config) }
end
