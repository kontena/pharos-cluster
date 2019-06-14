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
end
