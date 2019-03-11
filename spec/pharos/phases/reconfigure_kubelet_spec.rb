require "pharos/host/configurer"
require "pharos/phases/reconfigure_kubelet"

describe Pharos::Phases::ReconfigureKubelet do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::Transport::SSH) }
  subject { described_class.new(host) }

  before do
    allow(host).to receive(:transport).and_return(ssh)
  end

  describe '#call' do
    context 'when host is new' do
      it 'does not reconfigure kubelet' do
        allow(host).to receive(:new?).and_return(true)
        expect(subject).not_to receive(:reconfigure_kubelet)
        subject.call
      end
    end

    context 'when host is not new' do
      it 'reconfigures kubelet' do
        allow(host).to receive(:new?).and_return(false)
        expect(subject).to receive(:reconfigure_kubelet)
        subject.call
      end
    end
  end

  describe '#reconfigure_kubelet' do
    it 'reads kubelet config' do
      expect(ssh).to receive(:file).with('/var/lib/kubelet/config.yaml').and_return(double(:exist? => false))
      subject.reconfigure_kubelet
    end

    it 'upgrades kubelet config from configmap' do
      allow(ssh).to receive(:file).with('/var/lib/kubelet/config.yaml').and_return(double(:exist? => true, :read => 'config'))
      expect(ssh).to receive(:exec!).with("sudo kubeadm upgrade node config --kubelet-version #{Pharos::KUBE_VERSION}")
      subject.reconfigure_kubelet
    end

    context 'when kubelet config has been changed' do
      it 'restarts kubelet service' do
        kubelet_config = double(:exist? => true)
        allow(kubelet_config).to receive(:read).and_return('foo', 'bar') # config has been updated between reads
        allow(ssh).to receive(:file).with('/var/lib/kubelet/config.yaml').and_return(kubelet_config)
        allow(ssh).to receive(:exec!).with("sudo kubeadm upgrade node config --kubelet-version #{Pharos::KUBE_VERSION}")

        expect(ssh).to receive(:exec!).with('sudo systemctl restart kubelet')
        subject.reconfigure_kubelet
      end
    end

    context 'when kubelet config has NOT been changed' do
      it 'does not restart kubelet service' do
        kubelet_config = double(:exist? => true)
        allow(kubelet_config).to receive(:read).and_return('foo')
        allow(ssh).to receive(:file).with('/var/lib/kubelet/config.yaml').and_return(kubelet_config)
        allow(ssh).to receive(:exec!).with("sudo kubeadm upgrade node config --kubelet-version #{Pharos::KUBE_VERSION}")

        expect(ssh).not_to receive(:exec!).with('sudo systemctl restart kubelet')
        subject.reconfigure_kubelet
      end
    end
  end
end
