require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./addons/helm/addon.rb"

describe Pharos::AddonManager.addons['helm'] do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { {} }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject do
    described_class.new(config, enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client })
  end

  describe "#build_args" do
    it "adds set options" do
      chart = RecursiveOpenStruct.new(
        name: "stable/redis",
        set: {
          foo: "bar"
        }
      )
      args = subject.build_args(chart)
      expect(args.join(' ')).to include('--set foo=bar')
    end

    it "adds version" do
      chart = RecursiveOpenStruct.new(
        name: "stable/redis",
        version: "4.0.0"
      )
      args = subject.build_args(chart)
      expect(args.join(' ')).to include('--version 4.0.0')
    end

    it "adds namespace" do
      chart = RecursiveOpenStruct.new(
        name: "stable/redis",
        namespace: "foo"
      )
      args = subject.build_args(chart)
      expect(args.join(' ')).to include('--namespace foo')
    end
  end
end
