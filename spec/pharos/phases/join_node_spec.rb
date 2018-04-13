require 'pharos/config'
require 'pharos/phases/join_node'

describe Pharos::Phases::JoinNode do
  let(:host) { double(:host, address: '10.10.10.2', user: 'root', ssh_key_path: '~/.ssh/id_rsa.pub') }
  let(:master) { double(:master) }
  let(:subject) { described_class.new(host, master) }
  let(:join_cmd) { 'kubeadm join --token 531bb9.d1637f0a9b6af2ba 10.10.10.1:6443 --discovery-token-ca-cert-hash sha256:98d563efbb07a11cde93884394ba1d266912def377bfadc65d01a3bcc0ddd30d'.split(' ') }

  describe '#rewrite_api_address' do
    it 'rewrites address with local proxy' do
      expect(subject.rewrite_api_address(join_cmd)).to include(described_class::PROXY_ADDRESS)
    end
  end
end