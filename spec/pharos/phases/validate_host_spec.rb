require 'pharos/phases/validate_host'

describe Pharos::Phases::ValidateHost do
  let(:network_config) { {} }
  let(:host) {
    Pharos::Configuration::Host.new(
      address: '192.0.2.1',
      role: 'master'
    )
  }

  let(:config) {
    Pharos::Config.new(
      hosts: [host],
      network: network_config
    )
  }

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, config: config) }

  before do
    allow(host).to receive(:ssh).and_return(ssh)
  end

  describe '#check_role' do
    let(:role) { 'worker' }
    let(:host) { Pharos::Configuration::Host.new(
      address: '192.0.2.1',
      role: role
    ) }
    let(:checks) { {
      'ca_exists' => false,
      'api_healthy' => false,
      'kubelet_configured' => false
    } }
    before do
      host.checks = checks
    end
    subject { described_class.new(host, config: config) }

    context 'for a worker node' do
      let(:role) { 'worker' }

      context 'that is unconfigured' do
        let(:checks) { {
          'ca_exists' => false,
          'api_healthy' => false,
          'kubelet_configured' => false
        } }

        it 'does not raise' do
          expect{ subject.check_role }.to_not raise_error
        end
      end

      context 'that is configured as a worker' do
        let(:checks) { {
          'ca_exists' => false,
          'api_healthy' => false,
          'kubelet_configured' => true
        } }

        it 'does not raise' do
          expect{ subject.check_role }.to_not raise_error
        end
      end

      context 'that is configured as a master' do
        let(:checks) { {
          'ca_exists' => true,
          'api_healthy' => true,
          'kubelet_configured' => true
        } }

        it 'does not raise' do
          expect{ subject.check_role }.to raise_error(Pharos::InvalidHostError)
        end
      end
    end

    context 'for a master node' do
      let(:role) { 'master' }

      context 'that is unconfigured' do
        let(:checks) { {
          'ca_exists' => false,
          'api_healthy' => false,
          'kubelet_configured' => false
        } }

        it 'does not raise' do
          expect{ subject.check_role }.to_not raise_error
        end
      end

      context 'that is configured as a worker' do
        let(:checks) { {
          'ca_exists' => false,
          'api_healthy' => false,
          'kubelet_configured' => true
        } }

        it 'raises' do
          expect{ subject.check_role }.to raise_error(Pharos::InvalidHostError)
        end
      end

      context 'that is configured as a master' do
        let(:checks) { {
          'ca_exists' => true,
          'api_healthy' => true,
          'kubelet_configured' => true
        } }

        it 'does not raise' do
          expect{ subject.check_role }.to_not raise_error
        end
      end
    end
  end

  describe '#validate_unique_hostnames' do
    let(:host2) { Pharos::Configuration::Host.new(address: '192.0.2.2') }
    let(:host3) { Pharos::Configuration::Host.new(address: '192.0.2.3') }

    let(:config) { Pharos::Config.new(hosts: [host, host2, host3]) }

    context 'no duplicate hostnames' do
      before do
        config.hosts.each_with_index { |h, i| h.hostname = "host-#{i}" }
      end

      it 'does not raise if no duplicates' do
        expect { subject.validate_unique_hostnames }.not_to raise_error
      end
    end

    context 'duplicate hostnames' do
      before do
        config.hosts.each { |h| h.hostname = "foo" }
      end

      it 'raises if duplicates' do
        expect{ subject.validate_unique_hostnames }.to raise_error(Pharos::InvalidHostError, "Duplicate hostname foo for hosts 192.0.2.2,192.0.2.3")
      end
    end
  end

  describe '#validate_routes' do
    before do
      host.routes = routes
    end

    context 'for an unconfigured host' do
      let(:routes) { [
        Pharos::Configuration::Host::Route.new(prefix: 'default', via: '192.0.2.1', dev: 'eth0'),
        Pharos::Configuration::Host::Route.new(prefix: '192.0.2.0/24', dev: 'eth0', proto: 'kernel'),
        Pharos::Configuration::Host::Route.new(prefix: '172.17.0.0/16', dev: 'docker0', proto: 'kernel'),
      ] }

      context 'with non-overlapping calico routes' do
        let(:network_config) { {
          provider: 'calico',
          service_cidr: '10.96.0.0/12',
          pod_network_cidr: '10.32.0.0/12',
        }}

        it 'validates' do
          expect{subject.validate_routes}.to_not raise_error
        end
      end

      context 'with overlapping calico pod network routes' do
        let(:network_config) { {
          provider: 'calico',
          service_cidr: '10.96.0.0/12',
          pod_network_cidr: '172.16.0.0/12',
        }}

        it 'fails validation' do
          expect{subject.validate_routes}.to raise_error(RuntimeError, /Overlapping host routes for .network.pod_network_cidr/)
        end
      end

      context 'with overlapping calico service routes' do
        let(:network_config) { {
          provider: 'calico',
          service_cidr: '172.16.0.0/12',
          pod_network_cidr: '10.32.0.0/12',
        }}

        it 'fails validation' do
          expect{subject.validate_routes}.to raise_error(RuntimeError, /Overlapping host routes for .network.service_cidr/)
        end
      end

      context 'with overlapping weave pod network routes' do
        let(:network_config) { {
          provider: 'weave',
          service_cidr: '10.96.0.0/12',
          pod_network_cidr: '172.16.0.0/12',
        }}

        it 'fails validation' do
          expect{subject.validate_routes}.to raise_error(RuntimeError, /Overlapping host routes for .network.pod_network_cidr/)
        end
      end
    end

    context 'for an configured calico host' do
      let(:network_config) { {
        provider: 'calico',
        service_cidr: '10.96.0.0/12',
        pod_network_cidr: '10.32.0.0/12',
      }}
      let(:routes) { [
        Pharos::Configuration::Host::Route.new(prefix: 'default', via: '192.0.2.1', dev: 'eth0'),
        Pharos::Configuration::Host::Route.new(prefix: '192.0.2.0/24', dev: 'eth0', proto: 'kernel'),
        Pharos::Configuration::Host::Route.new(prefix: '172.17.0.0/16', dev: 'docker0', proto: 'kernel'),
        Pharos::Configuration::Host::Route.new(type: 'blackhole', prefix: '10.32.0.0/24', proto: 'bird'),
        Pharos::Configuration::Host::Route.new(prefix: '10.32.0.39', dev: 'cali5f1ddd73716', options: 'scope link'),
        Pharos::Configuration::Host::Route.new(prefix: '10.32.1.0/24', via: '192.0.2.10', dev: 'tunl0', proto: 'bird', options: 'onlink'),
      ] }

      it 'validates' do
        expect{subject.validate_routes}.to_not raise_error
      end
    end

    context 'for a configured weave host' do
      let(:network_config) { {
        provider: 'weave',
        service_cidr: '10.96.0.0/12',
        pod_network_cidr: '10.32.0.0/12',
      }}
      let(:routes) { [
        Pharos::Configuration::Host::Route.new(prefix: 'default', via: '192.0.2.1', dev: 'eth0'),
        Pharos::Configuration::Host::Route.new(prefix: '192.0.2.0/24', dev: 'eth0', proto: 'kernel'),
        Pharos::Configuration::Host::Route.new(prefix: '172.17.0.0/16', dev: 'docker0', proto: 'kernel'),
        Pharos::Configuration::Host::Route.new(prefix: '10.32.0.0/12', dev: 'weave', proto: 'kernel'),
      ] }

      it 'validates' do
        expect{subject.validate_routes}.to_not raise_error
      end
    end
  end
end
