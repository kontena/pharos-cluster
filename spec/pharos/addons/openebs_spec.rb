require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./addons/openebs/addon.rb"

describe Pharos::AddonManager.addons['openebs'] do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { {} }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject { described_class.new(config, enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client }) }

  describe '#validate' do
    context 'with more replicas than workers' do
      let(:config) {
         {default_storage_class: {replicas: 5}}
       }

      it 'raises' do
        expect { subject.validate }.to raise_error Pharos::InvalidAddonError, "Cannot set more replicas than workers"
      end
    end

    context 'with more replicas than workers' do
      let(:config) {
         {default_storage_class: {replicas: 1}}
       }

      it 'does not raise' do
        subject.validate
      end
    end
  end

  describe '#default_replica_count' do
    context 'with 2 workers' do
      before do
        cluster_config.hosts << Pharos::Configuration::Host.new(role: 'worker')
      end
      it 'returns number of workers' do
        expect(subject.default_replica_count).to eq(2)
      end
    end

    context 'with 5 workers' do
      before do
        4.times do
          cluster_config.hosts << Pharos::Configuration::Host.new(role: 'worker')
        end
      end

      it 'returns 3' do
        expect(subject.default_replica_count).to eq(3)
      end
    end
  end

  describe '#install' do
    context 'with default config' do
      let(:config) {
        { }
      }

      it 'applies stack with defaults' do
        expect(subject).to receive(:apply_resources).with(default_replicas: 1, default_capacity: '5G', is_default_class: false, default_storage_pool_path: '/var/openebs')

        subject.apply_install
      end
    end

    context 'with given config' do
      let(:config) {
        {
          default_storage_class: {
            replicas: 5,
            default_class: true,
            capacity: '12G'
          },
          default_storage_pool: {
            path: '/foo/bar'
          }
        }
      }

      it 'applies stack with given values' do
        expect(subject).to receive(:apply_resources).with(default_replicas: 5, default_capacity: '12G', is_default_class: true, default_storage_pool_path: '/foo/bar')

        subject.apply_install
      end
    end

    context "with given partial config" do
      let(:config) {
        {
          default_storage_class: {
            replicas: 5,
            default_class: true
          },
          default_storage_pool: {
            path: '/foo/bar'
          }
        }
      }

      it 'applies stack with default values' do
        expect(subject).to receive(:apply_resources).with(default_replicas: 5, default_capacity: '5G', is_default_class: true, default_storage_pool_path: '/foo/bar')

        subject.apply_install
      end
    end
  end
end
