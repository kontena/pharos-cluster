require 'pharos/phases/configure_weave'

describe Pharos::Phases::ConfigureWeave do
  let(:config) { double(:config) }
  subject { described_class.new(double, config: config) }

  describe '#configured_password', fakefs: true do
    it 'returns nil if no password set' do
      allow(config).to receive_message_chain('network.weave').and_return(nil)
      expect(subject.configured_password).to be_nil
    end

    it 'returns password file contents if given' do
      FakeFS do
        File.write('./weave_passwd', 'abcde123')
        allow(config).to receive_message_chain('network.weave.password').and_return('./weave_passwd')
        expect(subject.configured_password).to eq('abcde123')
      end
    end
  end

  describe '#initial_known_peers' do
    it 'returns nil if configmap does not exist and known_peers not set' do
      allow(config).to receive_message_chain('network.weave').and_return(nil)
      expect(subject).to receive_message_chain('kube_client.api.resource.get').and_raise(K8s::Error::NotFound.new(double, double, double, double))
      expect(subject.initial_known_peers).to be_nil
    end

    it 'returns known_peers if configmap does not exist' do
      allow(config).to receive_message_chain('network.weave.known_peers').and_return(['192.168.1.1'])
      expect(subject).to receive_message_chain('kube_client.api.resource.get').and_raise(K8s::Error::NotFound.new(double, double, double, double))
      expect(subject.initial_known_peers).to eq(['192.168.1.1'])
    end

    it 'returns value from configmap if it exists' do
      allow(config).to receive_message_chain('network.weave.known_peers').and_return(['192.168.1.1'])
      expect(subject).to receive_message_chain('kube_client.api.resource.get').and_return(
        K8s::Resource.new(
          data: {
            'known-peers': JSON.dump({peers: ['10.1.10.1']})
          }
        )
      )
      expect(subject.initial_known_peers).to eq(['10.1.10.1'])
    end
  end
end
