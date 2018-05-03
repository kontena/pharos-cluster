require "pharos/addons/open_ebs"

describe Pharos::Addons::OpenEbs do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:cpu_arch) { double(:cpu_arch ) }
  let(:master) { double(:host, address: '1.1.1.1') }

  describe '#validate' do
    context 'with more replicas than workers' do
      it 'raises' do
        config = {default_replicas: 5}
        subject = described_class.new(config, enabled: true, master: master, cpu_arch: cpu_arch, cluster_config: cluster_config)
        expect { subject.validate }.to raise_error Pharos::InvalidAddonError
      end
    end

    context 'with more replicas than workers' do
      it 'does not raise' do
        config = {default_replicas: 1}
        subject = described_class.new(config, enabled: true, master: master, cpu_arch: cpu_arch, cluster_config: cluster_config)
        subject.validate
      end
    end
  end

  describe '#default_replica_count' do
    context 'with 2 workers' do
      it 'returns number of workers' do
        cluster_config.hosts << Pharos::Configuration::Host.new(role: 'worker')
        subject = described_class.new({}, enabled: true, master: master, cpu_arch: cpu_arch, cluster_config: cluster_config)
        expect(subject.default_replica_count).to eq(2)
      end
    end

    context 'with 5 workers' do
      it 'returns 3' do
        4.times do
          cluster_config.hosts << Pharos::Configuration::Host.new(role: 'worker')
        end
        subject = described_class.new({}, enabled: true, master: master, cpu_arch: cpu_arch, cluster_config: cluster_config)
        expect(subject.default_replica_count).to eq(3)
      end
    end
  end

end
