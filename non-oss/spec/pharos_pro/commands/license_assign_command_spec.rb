require 'securerandom'

describe Pharos::LicenseAssignCommand do
  subject { described_class.new('') }

  let(:license_key) { "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
  let(:host) { Pharos::Configuration::Host.new(address: '127.0.0.1', role: 'master') }
  let(:config) { Pharos::Config.new(hosts: [host], name: 'name') }
  let(:ssh) { instance_double(Pharos::Transport::SSH) }
  let(:http_client) { spy }
  let(:cluster_manager) { instance_double(Pharos::ClusterManager) }
  let(:license_token) { 'abcd' }
  let(:success_response) { JSON.dump(data: { attributes: { 'license-token': { token: license_token, jwt: '123' } } }) }
  let(:token) { instance_double(Pharos::LicenseKey, valid?: true, token: '123') }
  let(:cluster_context) { { 'cluster-id' => '6c6289c0-1fb0-11e9-bac4-02f41f34da68' } }

  before do
    allow(subject).to receive(:decorate_license).and_return('')
    allow(subject).to receive(:config_yaml).and_return(double(dirname: __dir__))
    allow(subject).to receive(:load_config).and_return(config)
    allow(host).to receive(:transport).and_return(ssh)
    allow(Pharos::LicenseKey).to receive(:new).with('123', cluster_id: '6c6289c0-1fb0-11e9-bac4-02f41f34da68').and_return(token)
    stub_const("Excon", http_client)
    allow(ssh).to receive(:connect)
    allow(cluster_manager).to receive(:load).and_return true
    allow(cluster_manager).to receive(:gather_facts).and_return true
    allow(cluster_manager).to receive(:context).and_return cluster_context
    allow(subject).to receive(:cluster_manager).and_return(cluster_manager)
  end

  describe '#execute' do
    before do
      allow(http_client).to receive(:post).and_return(double(body: success_response))
    end

    context '--cluster-name given' do
      it 'signals error unless --cluster-id also given' do
        expect{subject.run(%w(--cluster-name abcd))}.to raise_error(Clamp::UsageError, /cluster-id required/)
      end
    end

    context '--cluster-id given' do
      it 'signals error unless --cluster-name also given' do
        expect{subject.run(%w(--cluster-id abcd))}.to raise_error(Clamp::UsageError, /cluster-name required/)
      end
    end

    context '--cluster-name and --cluster-id given' do
      it 'assigns a license without loading configuration and outputs jwt' do
        expect(http_client).to receive(:post).and_return(double(body: success_response))
        expect(subject).not_to receive(:cluster_manager)
        expect(subject).not_to receive(:load_config)
        expect{subject.run(%w(--cluster-id 6c6289c0-1fb0-11e9-bac4-02f41f34da68 --cluster-name defg) + [license_key])}.to output("123\n").to_stdout
      end
    end

    context 'cluster-info not found' do
      let(:cluster_context) { { } }

      it 'signals error' do
        expect{subject.run([license_key])}.to raise_error(Clamp::ExecutionError, /Fail.*cluster id/)
      end
    end

    it 'runs kubectl on master' do
      expect(ssh).to receive(:exec!).with("kubectl create secret generic pharos-license --namespace=kube-system --from-literal='license.jwt=123' --dry-run -o yaml | kubectl apply -f -")
      expect{subject.run([license_key])}.to output(/Assigned the subscription token/).to_stdout
    end
  end
end
