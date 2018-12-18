require 'pharos/phases/gather_facts'

describe Pharos::Phases::GatherFacts do
  let(:host) do
    Pharos::Configuration::Host.new(
      address: '192.0.2.1',
      role: 'master'
    )
  end

  let(:config) { Pharos::Config.new(hosts: [host]) }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(config.hosts[0], config: config) }

  before do
    allow(host).to receive(:ssh).and_return(ssh)
  end

  describe '#private_interface_address' do
    let(:iface) { 'eth0' }
    before do
      allow(ssh).to receive(:exec!).with(/ip -o addr show/).and_return(ip_addr)
    end

    context "for an interface configured with a private IP" do
      let(:ip_addr) { <<~EOM
        2: eth1    inet 192.168.0.10/24 brd 192.168.0.255 scope global eth0\       valid_lft forever preferred_lft forever
      EOM
      }

      it "returns the private IP" do
        expect(subject.private_interface_address('eth1')).to eq '192.168.0.10'
      end
    end

    context "for an interface that is not configured" do
      let(:ip_addr) { <<~EOM
      EOM
      }

      it "returns nil" do
        expect(subject.private_interface_address('eth1')).to eq nil
      end
    end

    context "with a public and private IP on the same interface" do
      let(:ip_addr) { <<~EOM
        2: eth0    inet 192.0.2.1/24 brd 192.0.2.255 scope global eth0\       valid_lft forever preferred_lft forever
        2: eth0    inet 10.18.0.5/16 brd 10.18.255.255 scope global eth0\       valid_lft forever preferred_lft forever
      EOM
      }

      it "returns the private IP" do
        expect(subject.private_interface_address('eth0')).to eq '10.18.0.5'
      end
    end
  end

  describe '#get_resolvconf' do
    let(:file) { instance_double Pharos::SSH::RemoteFile }
    let(:file_content) { "" }
    let(:file_readlink) { nil }

    before do
      allow(ssh).to receive(:file).with('/etc/resolv.conf').and_return(file)
      allow(file).to receive(:lines).and_return(file_content.lines)
      allow(file).to receive(:readlink).and_return(file_readlink)
    end

    context 'for a normal resolv.conf' do
      let(:file_content) { "# nameserver config\nnameserver 8.8.8.8\n" }

      it 'returns ok' do
        expect(subject.read_resolvconf).to eq Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: false,
          systemd_resolved_stub: false,
        )
      end
    end

    context 'for a normal resolv.conf with localhost' do
      let(:file_content) { "nameserver 127.0.0.53" }

      it 'returns nameserver_localhost' do
        expect(subject.read_resolvconf).to eq Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: true,
          systemd_resolved_stub: false,
        )
      end
    end

    context 'for a normal resolv.conf with ipv6 localhost' do
      let(:file_content) { "nameserver ::1" }

      it 'returns nameserver_localhost' do
        expect(subject.read_resolvconf).to eq Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: true,
          systemd_resolved_stub: false,
        )
      end
    end

    context 'for a systemd-resolved resolv.conf stub' do
      let(:file_content) { "nameserver 127.0.0.53" }
      let(:file_readlink) { '../run/systemd/resolve/stub-resolv.conf' }

      it 'returns systemd_resolved_stub' do
        expect(subject.read_resolvconf).to eq Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: true,
          systemd_resolved_stub: true,
        )
      end
    end

    context 'for a non-resolved resolv.conf symlink' do
      let(:file_content) { "nameserver 8.8.8.8" }
      let(:file_readlink) { '/run/resolvconf/resolv.conf' }

      it 'returns ok' do
        expect(subject.read_resolvconf).to eq Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: false,
          systemd_resolved_stub: false,
        )
      end
    end
  end

  describe '#read_routes' do
    let(:routes) { [
      'default via 192.0.2.1 dev eth0 onlink',
      '192.0.2.0/24 dev eth0  proto kernel  scope link  src 192.0.2.11',
      'wtf',
    ] }

    before do
      allow(ssh).to receive(:exec!).with('sudo ip route').and_return(routes.join "\n" + "\n")
    end

    it "returns valid routes" do
      expect(subject.read_routes.map{|route| {prefix: route.prefix, via: route.via, dev: route.dev}}).to eq [
        {prefix: 'default', via: '192.0.2.1', dev: 'eth0'},
        {prefix: '192.0.2.0/24', via: nil, dev: 'eth0'},
      ]
    end
  end

  describe '#hostname' do
    it 'returns lowercase hostname' do
      allow(ssh).to receive(:exec!).with('hostname -s').and_return('host-AAA101')
      expect(subject.hostname).to eq('host-aaa101')
    end

    it 'uses full hostname for aws' do
      allow(config).to receive(:cloud).and_return(Pharos::Configuration::Cloud.new(provider: 'aws'))
      expect(ssh).to receive(:exec!).with('hostname -f').and_return('host-01.mydomain.local')
      subject.hostname
    end

    it 'uses full hostname for vsphere' do
      allow(config).to receive(:cloud).and_return(Pharos::Configuration::Cloud.new(provider: 'vsphere'))
      expect(ssh).to receive(:exec!).with('hostname -f').and_return('host-01.mydomain.local')
      subject.hostname
    end

    it 'uses short hostname' do
      expect(ssh).to receive(:exec!).with('hostname -s').and_return('host-01.mydomain.local')
      subject.hostname
    end
  end
end
