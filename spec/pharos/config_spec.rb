describe Pharos::Config do
  let(:hosts) { [
    { 'address' => '192.0.2.1', 'role' => 'master' },
  ] }
  let(:data) { {
      'hosts' => hosts,
  } }

  subject { described_class.load(data) }

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

    context 'kube_client' do
      let(:data) { { 'hosts' => [ { 'address' => '192.0.2.1', 'role' => 'master' } ] } }
      let(:kubeconfig) { {}  }

      it 'creates a kube client' do
        expect(Pharos::Kube).to receive(:client).with('192.0.2.1',kubeconfig, 6443)
        subject.kube_client(kubeconfig)
      end

      context 'with bastion host' do
        let(:master) { Pharos::Configuration::Host.new('address' => '192.0.2.1', 'role' => 'master', 'bastion' => { 'address' => '192.0.2.2', 'user' => 'bastion' }) }
        let(:data) { { 'hosts' => [ { 'address' => '192.0.2.1', 'role' => 'master', 'bastion' => { 'address' => '192.0.2.2', 'user' => 'bastion' } } ] } }
        let(:bastion) { Pharos::Configuration::Bastion.new('address' => '192.0.2.2', 'user' => 'bastion') }
        let(:bastion_host) { instance_double(Pharos::Configuration::Host) }
        let(:ssh) { instance_double(Pharos::SSH::Client) }

        before do
          allow(subject).to receive(:master_host).and_return(master)
          allow(master).to receive(:bastion).and_return(bastion)
          allow(bastion).to receive(:host).and_return(bastion_host)
          allow(bastion_host).to receive(:ssh).and_return(ssh)
          allow(master).to receive(:api_address).and_return('api.example.com')
        end

        it 'creates a kube client through ssh' do
          expect(Pharos::Kube).to receive(:client).with('localhost', kubeconfig, 9999)
          expect(ssh).to receive(:gateway).with('api.example.com', 6443).and_return(9999)
          subject.kube_client(kubeconfig)
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
