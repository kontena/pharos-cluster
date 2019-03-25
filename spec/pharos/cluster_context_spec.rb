describe Pharos::ClusterContext do
  context 'boolean aliases' do
    it 'return the value of boolean field' do
      expect(described_class.new(force: true).force?).to be_truthy
    end
  end

  context 'settable attributes' do
    subject { described_class.new }

    it 'allow to set values' do
      expect(subject.join_command).to be_nil
      subject.join_command = "hello"
      expect(subject.join_command).to eq "hello"
    end
  end

  context '#kube_client' do
    let(:kube_config) { {} }
    let(:k8s_config) { K8s::Config.new(kube_config) }
    let(:client) { double(:client) }
    subject { described_class.new(config: Pharos::Config.new(hosts: [{address: '192.168.0.1', role: 'master'}]), kube_config: kube_config) }

    before do
      allow(subject).to receive(:k8s_config).and_return(k8s_config)
    end

    it 'creates a client' do
      expect(K8s::Client).to receive(:config).with(k8s_config, server: "https://192.168.0.1:6443").and_return(client)
      expect(subject.kube_client).to eq client
    end

    context 'with bastion' do
      let(:master_host) { Pharos::Configuration::Host.new(address: '192.168.0.1', role: 'master', bastion: { address: '10.0.0.1', user: 'foo' }) }
      before do
        allow(subject).to receive(:master_host).and_return(master_host)
      end

      it 'creates a client through ssh gateway' do
        allow(master_host).to receive_message_chain("bastion.host.ssh.gateway").with('192.168.0.1', 6443).and_return(1234)
        expect(K8s::Client).to receive(:config).with(k8s_config, server: "https://localhost:1234").and_return(client)
        expect(subject.kube_client).to eq client
      end
    end
  end
end
