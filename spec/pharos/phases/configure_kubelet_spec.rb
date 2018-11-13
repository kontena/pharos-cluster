require "pharos/phases/configure_kubelet"

describe Pharos::Phases::ConfigureKubelet do
  let(:host_resolvconf) { Pharos::Configuration::Host::ResolvConf.new(
      nameserver_localhost: false,
      systemd_resolved_stub: false,
  ) }
  let(:host_osrelease) { Pharos::Configuration::OsRelease.new(
    id: 'ubuntu',
    version: '16.04',
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

  subject { described_class.new(host, config: config) }

  before(:each) do
    host.resolvconf = host_resolvconf

    allow(host).to receive(:cpu_arch).and_return(double(:cpu_arch, name: 'amd64'))
    allow(host).to receive(:os_release).and_return(host_osrelease)
  end

  describe '#build_systemd_dropin' do
    it "returns a systemd unit" do
      expect(subject.build_systemd_dropin).to eq <<~EOM
        [Service]
        Environment='KUBELET_EXTRA_ARGS=--node-ip=192.168.42.1 --hostname-override= --authentication-token-webhook=true --pod-infra-container-image=registry.pharos.sh/kontenapharos/pause:3.1'
        ExecStartPre=-/sbin/swapoff -a
      EOM
    end
  end

  describe "#kubelet_extra_args" do
    it 'returns extra args array' do
      expect(subject.kubelet_extra_args).to include(
        '--node-ip=192.168.42.1',
        '--hostname-override=',
        '--authentication-token-webhook=true'
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

      it 'enables read only port' do
        expect(subject.kubelet_extra_args).to include(
          '--read-only-port=10255'
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

      it 'does not add node ip' do
        expect(subject.kubelet_extra_args).not_to include(
          "--node-ip=#{host.peer_address}"
        )
      end
    end

    context "with a systemd-resolved stub" do
      let(:host_resolvconf) { Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: true,
          systemd_resolved_stub: true,
      ) }

      it "uses --resolv-conf" do
        expect(subject.kubelet_extra_args).to include '--resolv-conf=/run/systemd/resolve/resolv.conf'
      end
    end

    context "with a non-systemd-resolved localhost resolver" do
      let(:host_resolvconf) { Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: true,
          systemd_resolved_stub: false,
      ) }

      it "fails" do
        expect{subject.kubelet_extra_args}.to raise_error 'Host has /etc/resolv.conf configured with localhost as a resolver'
      end
    end

    context "for a CentOS host" do
      let(:host_osrelease) { Pharos::Configuration::OsRelease.new(
        id: 'centos',
        version: '7',
      ) }

      it "configures --cgroup-driver" do
        expect(subject.kubelet_extra_args).to include '--cgroup-driver=systemd'
      end
    end
  end
end
