require "pharos/phases/configure_kubelet"

describe Pharos::Phases::ConfigureKubelet do
  let(:host_resolvconf) { Pharos::Configuration::Host::ResolvConf.new(
      nameserver_localhost: false,
      systemd_resolved_stub: false,
  ) }
  let(:host) { Pharos::Configuration::Host.new(
    address: 'test',
    private_address: '192.168.42.1',
  ) }

  let(:config_network) { { }}
  let(:config) { Pharos::Config.new(
      hosts: [host],
      network: config_network,
      addons: {},
      etcd: {},
      kubelet: {read_only_port: false}
  ) }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, config: config, ssh: ssh) }

  before(:each) do
    host.resolvconf = host_resolvconf

    allow(host).to receive(:cpu_arch).and_return(double(:cpu_arch, name: 'amd64'))
  end

  describe '#build_systemd_dropin' do
    it "returns a systemd unit" do
      expect(subject.build_systemd_dropin).to eq <<~EOM
        [Service]
        Environment='KUBELET_EXTRA_ARGS=--read-only-port=0 --node-ip=192.168.42.1 --hostname-override= --pod-infra-container-image=quay.io/kontena/pause-amd64:3.1'
        Environment='KUBELET_DNS_ARGS=--cluster-dns=10.96.0.10 --cluster-domain=cluster.local'
        ExecStartPre=-/sbin/swapoff -a
      EOM
    end
  end

  describe "#kubelet_extra_args" do
    it 'returns extra args array' do
      expect(subject.kubelet_extra_args).to include(
        '--read-only-port=0',
        '--node-ip=192.168.42.1',
        '--hostname-override='
      )
    end

    context 'with kubelet config' do
      let(:config) { Pharos::Config.new(
        hosts: [host],
        network: {
          service_cidr: '172.255.0.0/16',
        },
        cloud: {
          provider: 'aws',
          config: './cloud-config'
        },
        addons: {},
        etcd: {},
        kubelet: { read_only_port: true}
      ) }

      it 'does not disable read only port' do
        expect(subject.kubelet_extra_args).not_to include(
          '--read-only-port=0'
        )
      end
    end

    context 'with cloud provider' do
      let(:config) { Pharos::Config.new(
        hosts: [host],
        network: {
          service_cidr: '172.255.0.0/16',
        },
        cloud: {
          provider: 'aws',
          config: './cloud-config'
        },
        addons: {},
        etcd: {},
        kubelet: {}
      ) }

      it 'adds cloud-provider arg' do
        expect(subject.kubelet_extra_args).to include(
          '--cloud-provider=aws'
        )
      end

      it 'adds cloud-config arg' do
        expect(subject.kubelet_extra_args).to include(
          '--cloud-config=/etc/pharos/kubelet/cloud-config'
        )
      end
    end
  end

  describe '#kubelet_dns_args' do
    it 'returns cluster service IP' do
      expect(subject.kubelet_dns_args).to eq [
        '--cluster-dns=10.96.0.10',
        '--cluster-domain=cluster.local',
      ]
    end

    context "with a different network.service_cidr" do
      let(:config_network) { {
          service_cidr: '172.255.0.0/16',
      } }

      it "uses the customized --cluster-dns" do
        expect(subject.kubelet_dns_args).to eq [
          '--cluster-dns=172.255.0.10',
          '--cluster-domain=cluster.local',
        ]
      end
    end
  end
end
