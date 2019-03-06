require "pharos/phases/configure_master"

describe Pharos::Kubeadm::InitConfig do
  let(:master) { Pharos::Configuration::Host.new(address: 'test', private_address: 'private', role: 'master') }
  let(:config_hosts_count) { 1 }

  let(:config) { Pharos::Config.new(
      hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new(role: 'worker') },
      network: {
        service_cidr: '1.2.3.4/16',
        pod_network_cidr: '10.0.0.0/16'
      },
      addons: {},
      etcd: {}
  ) }

  subject { described_class.new(config, master) }

  describe '#generate' do

    it 'comes with correct master addresses' do
      config.hosts << master
      config = subject.generate
      expect(config.dig('localApiEndpoint', 'advertiseAddress')).to eq('private')
    end

    context 'with cri-o configuration' do
      let(:master) { Pharos::Configuration::Host.new(address: 'test', container_runtime: 'cri-o') }
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {}
      ) }

      it 'comes with proper etcd endpoint config' do
        config = subject.generate
        expect(config.dig('nodeRegistration', 'criSocket')).to eq('/var/run/crio/crio.sock')
      end
    end
  end
end
