require "pharos/phases/configure_master"

describe Pharos::Kubeadm::KubeletConfig do
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
    context 'defaults' do

    end

    context 'with kubelet.read_only_port' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kubelet: {
          read_only_port: true,
        }
      ) }

      it 'configures readOnlyPort' do
        config = subject.generate
        expect(config['readOnlyPort']).to eq(10_255)
      end
    end

    context 'with kubelet.feature_gates' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kubelet: {
          feature_gates: {
            foo: true
          }

        }
      ) }

      it 'configures featureGates' do
        config = subject.generate
        expect(config['featureGates']).to eq({ foo: true })
      end
    end

    context 'with kubelet.cpu_cfs_quota' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kubelet: {}
      ) }

      it 'is true by default' do
        config = subject.generate
        expect(config['cpuCFSQuota']).to eq(true)
      end

      it 'is false only when set so' do
        cfg = Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {},
          kubelet: {
            cpu_cfs_quota: false
          }
        )
        config = described_class.new(cfg, master).generate
        expect(config['cpuCFSQuota']).to eq(false)
      end
    end

    context 'with kubelet.cpu_cfs_quota_period' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kubelet: kubelet_config
      ) }

      let(:kubelet_config) {}

      context "by default" do
        it 'is not set' do
          config = subject.generate
          expect(config['cpuCFSQuotaPeriod']).to be_nil
        end
      end

      context "when set" do
        let(:kubelet_config) {
          {cpu_cfs_quota_period: "5ms"}
        }
        it 'is set' do
          config = subject.generate
          expect(config['cpuCFSQuotaPeriod']).to eq("5ms")
        end
      end
    end
  end
end
