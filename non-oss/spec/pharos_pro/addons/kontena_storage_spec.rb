require 'pharos/addon_manager'
Pharos::AddonManager.load_addon './non-oss/pharos_pro/addons/kontena-storage/addon.rb'

describe Pharos::AddonManager.addons['kontena-storage'] do
  describe '.validate' do
    it 'passes valid config' do
      expect(described_class.validate({
        'enabled' => true,
        'data_dir' => '/var/lib/foo',
        'storage' => {
          'use_all_nodes' => true
        }

      }).success?).to be_truthy
    end
  end

  describe '#build_cluster_resource' do
    it 'returns a cluster resource' do
      subject = described_class.new({
        'enabled' => true,
        'data_dir' => '/var/lib/foo',
        'storage' => {
          'use_all_nodes' => true
        }

      }, cpu_arch: double, cluster_config: double, cluster_context: { 'kube_client' => double })
      resource = subject.build_cluster_resource
      expect(resource.spec.dataDirHostPath).to eq('/var/lib/foo')
      expect(resource.spec.storage.useAllNodes).to be_truthy
    end
  end
end
