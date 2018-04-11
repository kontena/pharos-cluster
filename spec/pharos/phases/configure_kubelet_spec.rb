require "pharos/phases/configure_kubelet"

describe Pharos::Phases::ConfigureKubelet do
  let(:host) { Pharos::Configuration::Host.new(address: 'test', private_address: '192.168.42.1') }

  let(:config) { Pharos::Config.new(
      hosts: [host],
      network: {},
      addons: {},
      etcd: {}
  ) }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, config: config, ssh: ssh) }

  describe '#build_systemd_dropin' do
    it "returns a systemd unit" do
      expect(subject.build_systemd_dropin).to eq <<~EOM
        [Service]
        Environment='KUBELET_EXTRA_ARGS=--read-only-port=0 --node-ip=192.168.42.1 --hostname-override='
        Environment='KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local'
        ExecStartPre=-/sbin/swapoff -a
      EOM
    end

    context "with a different network.service_cidr" do
      let(:config) { Pharos::Config.new(
          hosts: [host],
          network: {
            service_cidr: '172.255.0.0/16',
          },
          addons: {},
          etcd: {}
      ) }

      it "uses the customized --cluster-dns" do
        expect(subject.build_systemd_dropin).to match /KUBELET_DNS_ARGS=--cluster-dns=172.255.0.10 --cluster-domain=cluster.local/
      end
    end
  end
end
