require "kupo/config"
require "kupo/phases/configure_master"

describe Kupo::Phases::ConfigureMaster do
  let(:master) { Kupo::Configuration::Host.new(address: 'test', private_address: 'private') }
  let(:config_hosts_count) { 1 }

  let(:config) { Kupo::Config.new(
      hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
      network: {
        service_cidr: '1.2.3.4/16',
        pod_network_cidr: '10.0.0.0/16'
      },
      addons: {},
      etcd: {}
  ) }
  subject { described_class.new(master, config) }

  before :each do
    allow(Kupo::SSH::Client).to receive(:for_host)
  end

  describe '#config_yaml' do
    context 'with network configuration' do
      let(:config) { Kupo::Config.new(
        hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
        network: {
          service_cidr: '1.2.3.4/16',
          pod_network_cidr: '10.0.0.0/16'
        },
        addons: {},
        etcd: {}
      ) }

      it 'comes with correct subnets' do
        config = subject.generate_config
        expect(config.dig('networking', 'serviceSubnet')).to eq('1.2.3.4/16')
        expect(config.dig('networking', 'podSubnet')).to eq('10.0.0.0/16')
      end

    end

    it 'comes with correct master addresses' do
      config = subject.generate_config
      expect(config.dig('apiServerCertSANs')).to eq(['test', 'private'])
      expect(config.dig('api', 'advertiseAddress')).to eq('private')
    end

    it 'comes with no etcd config' do
      config = subject.generate_config
      expect(config.dig('etcd')).to be_nil
      expect(config.dig('etcd', 'endpoints')).to be_nil
      expect(config.dig('etcd', 'version')).to be_nil
    end

    context 'with etcd endpoint configuration' do
      let(:config) { Kupo::Config.new(
        hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {
          endpoints: ['ep1', 'ep2']
        }
      ) }

      it 'comes with proper etcd endpoint config' do
        config = subject.generate_config
        expect(config.dig('etcd', 'endpoints')).to eq(['ep1', 'ep2'])
      end
    end

    context 'with etcd certificate configuration' do

      let(:config) { Kupo::Config.new(
        hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {
          endpoints: ['ep1', 'ep2'],
          ca_certificate: 'ca-certificate.pem',
          certificate: 'certificate.pem',
          key: 'key.pem'
        }
      ) }

      it 'comes with proper etcd certificate config' do
        config = subject.generate_config
        expect(config.dig('etcd', 'caFile')).to eq('/etc/kupo/etcd/ca-certificate.pem')
        expect(config.dig('etcd', 'certFile')).to eq('/etc/kupo/etcd/certificate.pem')
        expect(config.dig('etcd', 'keyFile')).to eq('/etc/kupo/etcd/certificate-key.pem')
      end
    end

    context 'with cri-o configuration' do
      let(:master) { Kupo::Configuration::Host.new(address: 'test', container_runtime: 'cri-o') }
      let(:config) { Kupo::Config.new(
        hosts: (1..config_hosts_count).map { |i| Kupo::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {}
      ) }

      it 'comes with proper etcd endpoint config' do
        config = subject.generate_config
        expect(config.dig('criSocket')).to eq('/var/run/crio/crio.sock')
      end
    end
  end
end
