require 'pharos/config'
require 'pharos/phases/join_node'

describe Pharos::Phases::JoinNode do
  let(:host) {
    double(
      :host,
      address: '10.10.10.2',
      user: 'root',
      ssh_key_path: '~/.ssh/id_rsa.pub',
      container_runtime: 'docker',
      hostname: 'node-1'
    )
  }
  let(:master) { double(:master) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  let(:cluster_context) {
    {
      'join-command' => join_cmd
    }
  }
  let(:subject) { described_class.new(host, cluster_context: cluster_context) }
  let(:join_cmd) { 'kubeadm join --token 531bb9.d1637f0a9b6af2ba 127.0.0.1:6443 --discovery-token-ca-cert-hash sha256:98d563efbb07a11cde93884394ba1d266912def377bfadc65d01a3bcc0ddd30d' }

  before(:each) do
    allow(host).to receive(:ssh).and_return(ssh)
    allow(subject).to receive(:already_joined?).and_return(false)
  end

  describe '#call' do
    it 'joins via ssh' do
      expect(ssh).to receive(:exec!) do |cmd|
        expect(cmd).to include("sudo kubeadm join")
        expect(cmd).to include("--node-name #{host.hostname}")
      end
      subject.call
    end
  end
end
