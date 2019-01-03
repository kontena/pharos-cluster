require "pharos/phases/configure_master"

describe Pharos::Kubeadm::KubeProxyConfig do
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
    context 'with kube-proxy ipvs configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kube_proxy: {
          mode: 'ipvs',
        }
      ) }

      it 'configures kube-proxy' do
        config = subject.generate
        expect(config['mode']).to eq('ipvs')
      end
    end

    context 'with kube-proxy iptables configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kube_proxy: {
          mode: 'iptables',
        }
      ) }

      it 'configures kube-proxy' do
        config = subject.generate
        expect(config['mode']).to eq('iptables')
      end
    end
  end
end
