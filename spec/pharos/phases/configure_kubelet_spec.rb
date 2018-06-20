require "pharos/phases/configure_kubelet"

describe Pharos::Phases::ConfigureKubelet do
  let(:host) { 
    host = Pharos::Configuration::Host.new(address: 'test', private_address: '192.168.42.1')
    host.os_release = Pharos::Configuration::OsRelease.new(id: 'ubuntu', version: '16.04')
    host
  }

  let(:config) { Pharos::Config.new(
      hosts: [host],
      network: {},
      addons: {},
      etcd: {},
      kubelet: {read_only_port: false}
  ) }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, config: config, ssh: ssh) }

  before(:each) do
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

    context "with a different network.service_cidr" do
      let(:config) { Pharos::Config.new(
          hosts: [host],
          network: {
            service_cidr: '172.255.0.0/16',
          },
          addons: {},
          etcd: {},
          kubelet: {}
      ) }

      it "uses the customized --cluster-dns" do
        expect(subject.build_systemd_dropin).to match /KUBELET_DNS_ARGS=--cluster-dns=172.255.0.10 --cluster-domain=cluster.local/
      end
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

    context 'centos/rhel 7' do
      it 'adds kubelet extra args' do
        host.os_release = Pharos::Configuration::OsRelease.new(id: 'centos', version: '7')
        expect(subject.kubelet_extra_args).to include(
          '--runtime-cgroups=/systemd/system.slice', 
          '--kubelet-cgroups=/systemd/system.slice'
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
end
