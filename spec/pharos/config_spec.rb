describe Pharos::Config do
  let(:hosts) { [
    { 'address' => '192.0.2.1', 'role' => 'master' },
  ] }
  let(:data) { {
      'hosts' => hosts,
  } }

  subject { described_class.load(data) }

  describe '#dig' do
    let(:data) do
      {
        'hosts' => hosts,
        'network' => { 'provider' => 'calico' }
      }
    end

    it 'works like hash dig' do
      expect(subject.dig(:hosts, 0, :address)).to eq '192.0.2.1'
      expect(subject.dig('network', 'provider')).to eq 'calico'
      expect(subject.dig('network', 'firewall', 'enabled')).to be_nil
    end
  end

  describe 'hosts' do
    context 'invalid host address' do
      let(:hosts) { [
        { 'address' => ' 192.0.2.1', 'role' => 'master' },
      ] }
      it 'fails to load' do
        expect{subject}.to raise_error(Pharos::ConfigError) do |exc|
          expect(exc.errors[:hosts][0][:address][0]).to eq "is invalid"
        end
      end
    end

    context 'invalid host private address' do
      let(:hosts) { [
        { 'address' => '192.0.2.1', 'private_address' => '"127.0.0.1"', 'role' => 'master' },
      ] }
      it 'fails to load' do
        expect{subject}.to raise_error(Pharos::ConfigError) do |exc|
          expect(exc.errors[:hosts][0][:private_address][0]).to eq "is invalid"
        end
      end
    end


    context 'without hosts' do
      let(:data) { {} }

      it 'fails to load' do
        expect{subject}.to raise_error(Pharos::ConfigError) do |exc|
          expect(exc.errors).to include(:hosts)
        end
      end
    end

    context 'with empty hosts' do
      let(:data) { {
        'hosts' => []
      } }

      it 'fails to load' do
        expect{subject}.to raise_error(Pharos::ConfigError)  do |exc|
          expect(exc.errors).to include(:hosts)
        end
      end
    end

    describe 'taints' do
      let(:data) { {
        'hosts' => [
          { 'address' => '192.0.2.1', 'role' => 'master' },
        ]
      } }

      it 'loads as nil by default' do
        expect(subject.hosts.first.taints).to eq nil
      end

      context 'with nil taints' do
        let(:data) { {
          'hosts' => [
            { 'address' => '192.0.2.1', 'role' => 'master', 'taints' => nil },
          ]
        } }

        it 'fails' do
          expect{subject}.to raise_error(Pharos::ConfigError) do |error|
            expect(error.errors).to eq :hosts => { 0 => { :taints => [ "must be an array" ] } }
          end
        end
      end

      context 'with empty taints' do
        let(:data) { {
          'hosts' => [
            { 'address' => '192.0.2.1', 'role' => 'master', 'taints' => [] },
          ]
        } }

        it 'loads as empty' do
          expect(subject.hosts.first.taints).to eq []
        end
      end

      context 'with taints' do
        let(:data) { {
          'hosts' => [
            { 'address' => '192.0.2.1', 'role' => 'master', 'taints' => [
                { 'key' => 'test', 'effect' => 'NoSchedule' },
            ] },
          ]
        } }

        it 'loads taints' do
          expect(subject.hosts.first.taints).to eq [
            Pharos::Configuration::Taint.new(key: 'test', effect: 'NoSchedule'),
          ]
        end
      end

      context 'with invalid effect' do
        let(:data) { {
          'hosts' => [
            { 'address' => '192.0.2.1', 'role' => 'master', 'taints' => [
                { 'key' => 'test', 'effect' => 'NoTest' },
            ] },
          ]
        } }

        it 'fails' do
          expect{subject}.to raise_error(Pharos::ConfigError) do |error|
            expect(error.errors).to eq :hosts => { 0 => { :taints => { 0 => { :effect => [ "must be one of: NoSchedule, NoExecute" ] } } } }
          end
        end
      end
    end

    context 'ssh_port' do
      context 'using default port' do
        let(:data) { { 'hosts' => [ { 'address' => '192.0.2.1', 'user' => 'test', 'role' => 'master' } ] } }

        it 'uses port 22' do
          expect(Net::SSH).to receive(:start).with('192.0.2.1', 'test', hash_including(port: 22))
          subject.hosts.first.transport.connect
        end
      end

      context 'using custom port' do
        let(:data) { { 'hosts' => [ { 'address' => '192.0.2.1', 'user' => 'test', 'role' => 'master', 'ssh_port' => 2345 } ] } }

        it 'uses the defined custom port' do
          expect(Net::SSH).to receive(:start).with('192.0.2.1', 'test', hash_including(port: 2345))
          subject.hosts.first.transport.connect
        end
      end

      context 'using bastion' do
        let(:data) { { 'hosts' => [ { 'address' => '192.0.2.1', 'user' => 'test', 'role' => 'master', 'ssh_port' => 2345, 'bastion' => { 'address' => '192.0.2.3', 'user' => 'bastion', 'ssh_port' => 4567 } } ] } }
        let(:local_forward) { double }
        let(:forward_session) { double(forward: local_forward) }

        it 'uses port of bastion host on bastion and forwards custom port and connects to local port on localhost' do
          expect(subject.hosts.first.bastion.host.transport).to receive(:next_port).and_return(9999)
          expect(subject.hosts.first.bastion.host.transport).to receive(:ensure_event_loop)
          expect(local_forward).to receive(:local).with(9999, '192.0.2.1', 2345)
          expect(Net::SSH).to receive(:start).with('192.0.2.3', 'bastion', hash_including(port: 4567)).and_return(forward_session)
          expect(Net::SSH).to receive(:start).with('127.0.0.1', 'test', hash_including(port: 9999))
          subject.hosts.first.transport.connect
        end
      end
    end
  end

  describe '#master_hosts' do
    let(:data) { {
      'hosts' => [
        { 'address' => '192.0.2.1', 'role' => 'master'},
        { 'address' => '192.0.2.2', 'role' => 'master'},
        { 'address' => '192.0.2.3', 'role' => 'worker'},
      ]
    } }

    it 'returns hosts with role=master' do
      expect(subject.master_hosts.size).to eq(2)
      expect(subject.master_hosts.first.address).to eq('192.0.2.1')
      expect(subject.master_hosts.last.address).to eq('192.0.2.2')
    end

    it 'sorts masters by score' do
      subject.hosts[1].checks['api_healthy'] = true
      expect(subject.master_hosts.first.address).to eq('192.0.2.2')
    end
  end

  describe '#etcd_hosts' do
    let(:data) { {
      'hosts' => [
        { 'address' => '192.0.2.1', 'role' => 'master'},
        { 'address' => '192.0.2.2', 'role' => 'master'},
        { 'address' => '192.0.2.3', 'role' => 'worker'},
      ]
    } }

    it 'returns hosts with role=master' do
      expect(subject.etcd_hosts.size).to eq(2)
      expect(subject.etcd_hosts.first.address).to eq('192.0.2.1')
      expect(subject.etcd_hosts.last.address).to eq('192.0.2.2')
    end

    it 'sorts etcd hosts by score' do
      subject.hosts[1].checks['etcd_healthy'] = true
      expect(subject.etcd_hosts.first.address).to eq('192.0.2.2')
    end
  end

  describe 'kube_proxy' do
    it 'defaults to iptables' do
      expect(subject.kube_proxy.mode).to eq 'iptables'
    end

    context 'with invalid mode' do
      let(:data) { {
          'hosts' => hosts,
          'kube_proxy' => {
            'mode' => 'asdf',
          }
      } }

      it 'fails' do
        expect{subject}.to raise_error(Pharos::ConfigError)  do |exc|
          expect(exc.errors).to eq :kube_proxy => { :mode => [ "must be one of: userspace, iptables, ipvs" ] }
        end
      end
    end
  end

  describe 'etcd' do
    it 'loads without etcd config by default' do
      expect(subject.etcd).to eq nil
    end

    context 'without endpoints' do
      let(:data) { {
          'hosts' => hosts,
          'etcd' => {},
      } }

      it 'fails' do
        expect{subject}.to raise_error(Pharos::ConfigError)
      end
    end

    context 'with endpoints' do
      let(:data) { {
          'hosts' => hosts,
          'etcd' => {
            'endpoints' => [ 'https://192.168.1.2' ],
          }
      } }

      it 'loads' do
        expect(subject.etcd.endpoints).to eq [
          'https://192.168.1.2',
        ]
      end
    end
  end

  describe 'cloud' do
    it 'is nil by default' do
      expect(subject.cloud).to eq nil
    end

    context 'with empty config' do
      let(:data) { {
          'hosts' => hosts,
          'cloud' => { },
      } }

      it 'fails' do
        expect{subject}.to raise_error(Pharos::ConfigError)
      end
    end

    context 'with cloud provider' do
      let(:data) { {
          'hosts' => hosts,
          'cloud' => {
            'provider' => 'external',
          },
      } }

      it 'loads the provider' do
        expect(subject.cloud.provider).to eq 'external'
      end
    end

    context 'with invalid cloud config' do
      let(:data) { {
          'hosts' => hosts,
          'cloud' => {
            'provider' => "external",
            'config' => {}
          }
      } }

      it 'fails' do
        expect{subject}.to raise_error(Pharos::ConfigError)
      end
    end
  end

  describe 'kubelet' do
    it 'disables the readonly port by deault' do
      expect(subject.kubelet.read_only_port).to eq(false)
    end

    context 'with empty config' do
      let(:data) { {
          'hosts' => hosts,
          'kubelet' => {},
      } }

      it 'loads false' do
        expect(subject.kubelet.read_only_port).to eq false
      end
    end

    context 'with read_only_port: true' do
      let(:data) { {
        'hosts' => hosts,
        'kubelet' => {
          'read_only_port' => true,
        }
      } }

      it 'loads true' do
        expect(subject.kubelet.read_only_port).to eq true
      end
    end

    context 'with invalid read_only_port' do
      let(:data) { {
        'hosts' => hosts,
        'kubelet' => {
          'read_only_port' => 'foobar',
        }
      } }

      it 'fails' do
        expect{subject}.to raise_error(Pharos::ConfigError)
      end
    end
  end

  describe 'addons' do
    it 'returns empty addons by default' do
      expect(subject.addons).to eq({})
    end

    context 'with an empty hash' do
      let(:data) { {
        'hosts' => hosts,
        'addons' => {},
      } }

      it 'returns empty addons' do
        expect(subject.addons).to eq({})
      end
    end
  end

  describe 'admission_plugins' do
    it 'returns empty plugins by default' do
      expect(subject.admission_plugins).to be_nil
    end
  end
end
