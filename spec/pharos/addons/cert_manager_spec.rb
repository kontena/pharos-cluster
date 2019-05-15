require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./addons/cert-manager/addon.rb"

describe Pharos::AddonManager.addons['cert-manager'] do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { { foo: 'bar'} }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:kube_api_client) { instance_double(K8s::APIClient) }
  let(:kube_resource_client) { instance_double(K8s::ResourceClient) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject do
    described_class.new(config, enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client })
  end

  describe "#validate" do
    it "validates issuer server not to allow LE acme v1" do
      result = described_class.validate({enabled: true, issuer: {server: 'https://acme-v01.api.letsencrypt.org/directory', name: 'letsencrypt', email: 'foo'}})
      expect(result.success?).not_to be_truthy
      expect(result.errors.dig(:le_acme_v1)).not_to be_nil
    end

    it "accepts LE acme v2" do
      result = described_class.validate({enabled: true, issuer: {server: 'https://acme-v02.api.letsencrypt.org/directory', name: 'letsencrypt', email: 'foo'}})
      expect(result.success?).to be_truthy
    end
  end

  describe "#migrate_le_acme_issuers" do
    before do
      allow(kube_client).to receive(:api).with('certmanager.k8s.io/v1alpha1').and_return(kube_api_client)
      allow(kube_api_client).to receive(:resource).with('issuers', anything).and_return(kube_resource_client)
    end

    it "does not migrate if no issuers" do
      expect(kube_resource_client).to receive(:list).and_return([])
      expect(kube_client).not_to receive(:client_for_resource)

      subject.migrate_le_acme_issuers
    end

    it "does not migrate non-LE issuers" do
      expect(kube_resource_client).to receive(:list).and_return([K8s::Resource.new({spec: {acme: {server: 'foobar'}}})])
      expect(kube_client).not_to receive(:client_for_resource)

      subject.migrate_le_acme_issuers
    end

    it "migrates LE issuers" do
      le_issuer = K8s::Resource.new({
        metadata: {
          name: 'test',
          namespace: 'test-ns'
        },
        spec: {
          acme: {
            server: 'https://acme-v01.api.letsencrypt.org/directory'
          }
        }
      })
      expect(kube_resource_client).to receive(:list).and_return([le_issuer])
      expect(kube_client).to receive(:client_for_resource).and_return(kube_resource_client)

      expected_patch = {
        spec: {
          acme: {
            server: 'https://acme-v02.api.letsencrypt.org/directory'
          }
        }
      }

      expect(kube_resource_client).to receive(:merge_patch).with('test', expected_patch, namespace: 'test-ns', strategic_merge: false)

      subject.migrate_le_acme_issuers
    end
  end

  describe "#migrate_le_acme_cluster_issuers" do
    before do
      allow(kube_client).to receive(:api).with('certmanager.k8s.io/v1alpha1').and_return(kube_api_client)
      allow(kube_api_client).to receive(:resource).with('clusterissuers', anything).and_return(kube_resource_client)
    end

    it "does not migrate if no issuers" do
      expect(kube_resource_client).to receive(:list).and_return([])
      expect(kube_client).not_to receive(:client_for_resource)

      subject.migrate_le_acme_cluster_issuers
    end

    it "does not migrate non-LE issuers" do
      expect(kube_resource_client).to receive(:list).and_return([K8s::Resource.new({spec: {acme: {server: 'foobar'}}})])
      expect(kube_client).not_to receive(:client_for_resource)

      subject.migrate_le_acme_cluster_issuers
    end

    it "migrates LE issuers" do
      le_issuer = K8s::Resource.new({
        metadata: {
          name: 'test'
        },
        spec: {
          acme: {
            server: 'https://acme-v01.api.letsencrypt.org/directory'
          }
        }
      })
      expect(kube_resource_client).to receive(:list).and_return([le_issuer])
      expect(kube_client).to receive(:client_for_resource).and_return(kube_resource_client)

      expected_patch = {
        spec: {
          acme: {
            server: 'https://acme-v02.api.letsencrypt.org/directory'
          }
        }
      }

      expect(kube_resource_client).to receive(:merge_patch).with('test', expected_patch, strategic_merge: false)

      subject.migrate_le_acme_cluster_issuers
    end
  end
end
