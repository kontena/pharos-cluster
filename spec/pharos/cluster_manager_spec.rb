describe Pharos::ClusterManager do
  let(:hosts) do
    [ Pharos::Configuration::Host.new(address: '1.1.1.1', role: 'master') ]
  end

  let(:subject) do
    described_class.new(Pharos::Config.new(
      hosts: hosts
    ))
  end

  let(:fake_ssh) do
    double(:ssh)
  end

  before(:each) do
    hosts.each do |host|
      allow(host).to receive(:ssh).and_return(fake_ssh)
    end
  end

  describe '#disconnect' do
    it 'disconnects connected ssh clients' do
      expect(fake_ssh).to receive(:connected?).and_return(true)
      expect(fake_ssh).to receive(:disconnect)
      subject.disconnect
    end

    it 'does not disconnect not connected ssh clients' do
      expect(fake_ssh).to receive(:connected?).and_return(false)
      expect(fake_ssh).not_to receive(:disconnect)
      subject.disconnect
    end
  end
end