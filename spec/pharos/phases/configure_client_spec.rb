require 'pharos/config'
require 'pharos/phases/configure_client'

describe Pharos::Phases::ConfigureClient do
  let(:host) do
    Pharos::Configuration::Host.new(
      address: '10.10.10.2',
      user: 'root',
      ssh_key_path: '~/.ssh/id_rsa.pub',
      role: 'master'
    )
  end
  let(:config) { Pharos::Config.new(hosts: [host]) }

  let(:transport) { instance_double(Pharos::Transport::SSH) }
  let(:remote_file) { instance_double(Pharos::Transport::TransportFile) }
  let(:cluster_context) { {} }
  let(:kubeclient) { instance_double(K8s::Client) }
  let(:k8s_config) { instance_double(K8s::Config) }

  let(:subject) { described_class.new(host, config: config, cluster_context: cluster_context) }

  before(:each) do
    allow(host).to receive(:master_sort_score).and_return(0)
    allow(host).to receive(:transport).and_return(transport)
    allow(transport).to receive(:file).with('/etc/kubernetes/admin.conf').and_return(remote_file)
    allow(remote_file).to receive(:exist?).and_return(true)
    allow(kubeclient).to receive(:apis)
    allow(K8s::Config).to receive(:new).and_return(k8s_config)
  end

  describe '#call' do
    it 'loads kubeconfig from master and configures kubeclient through port forwarding' do
      expect(remote_file).to receive(:read).and_return('content')
      expect(transport).to receive(:forward).with('10.10.10.2', 6443).and_return(1234)
      expect(Pharos::Kube).to receive(:client).with('localhost', k8s_config, 1234).and_return(kubeclient)
      expect{subject.call}.to change{cluster_context}.from({}).to(hash_including('kube_client' => kubeclient))
    end
  end
end
