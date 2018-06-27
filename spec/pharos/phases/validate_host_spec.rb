require 'pharos/phases/validate_host'

describe Pharos::Phases::ValidateHost do
  let(:config) { Pharos::Config.new(
      hosts: [
        Pharos::Configuration::Host.new(
          address: '192.0.2.1',
          role: 'master'
        ),
      ],
  ) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(config.hosts[0], config: config, ssh: ssh) }

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
    subject { described_class.new(host, config: config, ssh: ssh) }

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
end
