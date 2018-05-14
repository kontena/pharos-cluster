describe Pharos::Config do
  let(:hosts) { [] }
  subject { described_class.new(
    hosts: hosts,
    api: {}
  ) }

  describe '#addons' do
    it 'returns empty addons by default' do
      expect(subject.addons).to eq({})
    end
  end

  describe '#kubelet' do
    let(:subject) do
      described_class.new({kubelet: {}})
    end
    it 'returns default kubelet config' do
      expect(subject.kubelet.read_only_port).to eq(false)
    end
  end

  context 'with three master hosts' do
    let(:master1) { Pharos::Configuration::Host.new(address: '192.0.2.1', role: 'master') }
    let(:master2) { Pharos::Configuration::Host.new(address: '192.0.2.2', role: 'master') }
    let(:master3) { Pharos::Configuration::Host.new(address: '192.0.2.3', role: 'master') }
    let(:hosts) { [master1, master2, master3] }

    context 'where the first one is unconfigured' do
      before do
        master1.checks = {
          'ca_exists' => false,
          'api_healthy' => false,
          'kubelet_configured' => false
        }
        master2.checks = {
          'ca_exists' => true,
          'api_healthy' => true,
          'kubelet_configured' => true
        }
        master3.checks = {
          'ca_exists' => true,
          'api_healthy' => true,
          'kubelet_configured' => true
        }
      end

      describe '#master_host' do
        it 'prefers the second master' do
          expect(subject.master_host).to eq master2
        end
      end

      describe 'api_endpoint' do
        it 'uses the second master' do
          expect(subject.api_endpoint).to eq '192.0.2.2'
        end
      end
    end
  end

  context 'with an API endpoint' do
    subject { described_class.new(api: { endpoint: 'kube.example.com' } ) }

    describe 'api_endpoint' do
      it 'uses the configured API endpoint' do
        expect(subject.api_endpoint).to eq 'kube.example.com'
      end
    end
  end
end
