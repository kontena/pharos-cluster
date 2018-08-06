require "pharos/phases/upgrade_master"

describe Pharos::Phases::UpgradeMaster do
  let(:master) { Pharos::Configuration::Host.new(address: 'test') }
  let(:config_hosts_count) { 1 }
  let(:config_dns_replicas) { nil }
  let(:config) { Pharos::Config.new(
      hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
      network: {
        dns_replicas: config_dns_replicas,
      },
      addons: {},
      etcd: {}
  ) }

  subject { described_class.new(master, config: config, master: master) }

  describe '#create_dns_patch_thread' do
    it 'patches coredns deployment' do

    end
  end
end