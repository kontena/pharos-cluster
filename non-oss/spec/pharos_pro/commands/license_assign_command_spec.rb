require 'securerandom'

describe Pharos::LicenseAssignCommand do
  subject { described_class.new('') }

  let(:license_key) { "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }
  let(:host) { Pharos::Configuration::Host.new(address: '127.0.0.1', role: 'master') }
  let(:config) { Pharos::Config.new(hosts: [host]) }
  let(:ssh) { instance_double(Pharos::Transport::SSH) }
  let(:http_client) { spy }
  let(:license_token) { 'abcd' }
  let(:success_response) { JSON.dump(data: { attributes: { 'license-token': { token: license_token } } }) }

  before do
    allow(subject).to receive(:config_yaml).and_return(double(dirname: __dir__))
    allow(subject).to receive(:load_config).and_return(config)
    allow(host).to receive(:transport).and_return(ssh)
    allow(ssh).to receive(:connect)
    allow(subject).to receive(:http_client).and_return(http_client)
    allow(subject).to receive(:license_key).and_return(license_key)
  end

  describe '#execute' do
    before do
      allow(subject).to receive(:validate_license_format)
      allow(http_client).to receive(:post).and_return(double(body: success_response))
      allow(ssh).to receive(:exec!)
      subject.run([])
    end

    it 'runs kubectl on master' do
      expect(ssh).to have_received(:exec!).with("kubectl create secret generic pharos-cluster --namespace=kube-system --from-literal=key=#{license_token} --dry-run -o yaml | kubectl apply -f -")
    end
  end

  describe '#validate_license_format' do
    context 'for a valid looking token' do
      it 'signals an usage error' do
        expect{subject.validate_license_format}.not_to raise_error
      end
    end

    context 'for an invalid looking token' do
      let(:license_key) { "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaz" }

      it 'signals an usage error' do
        expect{subject.validate_license_format}.to raise_error(Clamp::UsageError)
      end
    end
  end

  describe '#subscription_token' do
    context 'with a valid token' do
      before do
        allow(http_client).to receive(:post).and_return(double(body: success_response))
        subject.subscription_token
      end

      it 'issues a valid POST request' do
        expect(http_client).to have_received(:post) do |url, options|
          expect(url).to match %r{licenses/#{license_key}}
          expect(JSON.parse(options[:body])).to match hash_including(
            'data' => hash_including(
              'attributes' => hash_including(
                'description' => /pharos version .* on 127.0.0.1/
              )
            )
          )
        end
      end
    end

    context 'with an invalid token' do
     let(:failure_response) { JSON.dump(errors: [{ title: 'fail!' }]) }

      before do
        allow(subject).to receive(:license_key).and_return(license_key)
        allow(subject).to receive(:signal_error)
        allow(http_client).to receive(:post).and_return(double(body: failure_response))
        subject.subscription_token
      end

      it 'signals an error' do
        expect(subject).to have_received(:signal_error).with 'fail!'
      end
    end
  end
end
