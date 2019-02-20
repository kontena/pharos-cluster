describe Pharos::ClusterManager do
  let(:hosts) do
    [ Pharos::Configuration::Host.new(address: '1.1.1.1', role: 'master') ]
  end

  let(:subject) do
    described_class.new(Pharos::Config.new(
      hosts: hosts
    ))
  end

  let(:transport) do
    instance_double(Pharos::Transport::Base)
  end

  before(:each) do
    hosts.each do |host|
      allow(host).to receive(:transport).and_return(transport)
    end
  end

  describe '#disconnect' do
    it 'disconnects transports' do
      expect(transport).to receive(:disconnect)
      subject.disconnect
    end
  end
end
