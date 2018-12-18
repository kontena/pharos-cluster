require 'pharos/addon'
require 'pharos/kube'
require 'pharos_pro/addons/kontena-storage/addon'

RSpec.describe Pharos::Addons::KontenaStorage do
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

      }, kube_client: double, cpu_arch: double, cluster_config: double)
      resource = subject.build_cluster_resource
      expect(resource.spec.dataDirHostPath).to eq('/var/lib/foo')
      expect(resource.spec.storage.useAllNodes).to be_truthy
    end
  end
end
