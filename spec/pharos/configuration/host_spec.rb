require 'pharos/config'

describe Pharos::Configuration::Host do

  let(:subject) do
    described_class.new(
      address: '192.168.100.100',
      role: 'master',
      user: 'root'
    )
  end

  describe '#labels' do
    context 'for master' do
      it 'returns empty labels by default' do
        subject = described_class.new(
          address: '192.168.100.100',
          role: 'master',
          user: 'root'
        )
        expect(subject.labels).to eq(nil)
      end

      it 'returns given labels' do
        subject = described_class.new(
          address: '192.168.100.100',
          role: 'master',
          user: 'root',
          labels: {
            foo: 'bar',
            baz: 'baf'
          }
        )
        expect(subject.labels).to eq({foo: 'bar', baz: 'baf'})
      end
    end

    context 'for worker' do
      it 'returns given labels' do
        subject = described_class.new(
          address: '192.168.100.100',
          role: 'worker',
          user: 'root',
          labels: {
            foo: 'bar',
            baz: 'baf'
          }
        )
        expect(subject.labels).to eq({foo: 'bar', baz: 'baf'})
      end

      it 'returns default worker label' do
        subject = described_class.new(
          address: '192.168.100.100',
          role: 'worker',
          user: 'root'
        )
        expect(subject.labels).to eq({ 'node-role.kubernetes.io/worker': "" })
      end
    end
  end

  describe '#short_hostname' do
    let(:hostname) { nil }

    before do
      subject.hostname = hostname if hostname
    end

    it 'returns nil if no hostname is set' do
      expect(subject.short_hostname).to eq nil
    end

    context 'with a short hostname' do
      let(:hostname) { 'test' }

      it 'returns the hostname as-is' do
        expect(subject.short_hostname).to eq 'test'
      end
    end

    context 'with an fqdn hostname' do
      let(:hostname) { 'test.example.com' }

      it 'returns the short hostname' do
        expect(subject.short_hostname).to eq 'test'
      end
    end
  end

  describe '#configurer' do
    before(:all) do
      Pharos::Host::Configurer.load_configurers
    end

    it 'returns nil on non-supported os release' do
      allow(subject).to receive(:os_release).and_return(double(:os_release, id: 'foo', version: 'bar'))
      expect(subject.configurer).to be_nil
    end

    it 'returns os release when supported' do
      allow(subject).to receive(:os_release).and_return(double(:os_release, id: 'ubuntu', version: '16.04'))
      expect(subject.configurer).to be_kind_of(Pharos::Host::UbuntuXenial)
    end
  end

  describe '#crio?' do
    it 'returns true if container runtime is crio' do
      allow(subject).to receive(:container_runtime).and_return('cri-o')
      expect(subject.crio?).to be_truthy
    end

    it 'returns false if container runtime is not crio' do
      allow(subject).to receive(:container_runtime).and_return('docker')
      expect(subject.crio?).to be_falsey
    end
  end

  describe '#docker?' do
    it 'returns true if container runtime is docker' do
      allow(subject).to receive(:docker?).and_return(true)
      expect(subject.docker?).to be_truthy
    end

    it 'returns false if container runtime is not docker' do
      allow(subject).to receive(:container_runtime).and_return('cri-o')
      expect(subject.docker?).to be_falsey
    end
  end

  describe '#overlapping_routes' do
    let(:routes) { [
      Pharos::Configuration::Host::Route.new(prefix: 'default', via: '192.0.2.1', dev: 'eth0', options: 'onlink'),
      Pharos::Configuration::Host::Route.new(prefix: '10.18.0.0/16', dev: 'eth0', proto: 'kernel', options: 'scope link  src 10.18.0.13'),
      Pharos::Configuration::Host::Route.new(prefix: '192.0.2.0/24', dev: 'eth0', proto: 'kernel', options: 'scope link  src 192.0.2.11'),
      Pharos::Configuration::Host::Route.new(prefix: '172.17.0.0/16', dev: 'docker0', proto: 'kernel', options: 'scope link  src 172.17.0.1 linkdown'),
    ] }

    subject do
      subject = described_class.new(
        address: '192.0.2.1',
      )
      subject.routes = routes
      subject
    end

    it "finds an overlapping route for a 172.16.0.0/12" do
      expect(subject.overlapping_routes('172.16.0.0/12').map{|route| route.prefix}).to eq ['172.17.0.0/16']
    end

    it "finds an overlapping route for a 10.18.128.0/18" do
      expect(subject.overlapping_routes('10.18.128.0/18').map{|route| route.prefix}).to eq ['10.18.0.0/16']
    end

    it "does not find any overlapping routes for 172.16.0.0/24" do
      expect(subject.overlapping_routes('172.16.0.0/24').map{|route| route.prefix}).to eq []
    end
  end
end
