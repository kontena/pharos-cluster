require 'pharos/phases/validate_cluster_hosts'

describe Pharos::Phases::ValidateClusterHosts do
  let(:config) { Pharos::Config.new(
      hosts: [
        Pharos::Configuration::Host.new(
          address: '192.0.2.1',
        ),
        Pharos::Configuration::Host.new(
          address: '192.0.2.2',
        ),
        Pharos::Configuration::Host.new(
          address: '192.0.2.3',
        ),
      ],
  ) }

  subject { described_class.new(config.hosts[0], config: config) }


  describe '#call' do
    context 'no duplicate hostnames' do
      it 'does not raise if no duplicates' do
        config.hosts[0].hostname = "host-0"
        config.hosts[1].hostname = "host-1"
        config.hosts[2].hostname = "host-2"

        subject.call
      end
    end

    context 'duplicate hostnames' do
      it 'raises if duplicates' do
        config.hosts[0].hostname = "foo"
        config.hosts[1].hostname = "foo"
        config.hosts[2].hostname = "foo"

        expect{ subject.call }.to raise_error(Pharos::InvalidHostError, "Duplicate hostname foo for hosts 192.0.2.2,192.0.2.3")
      end
    end
  end

end
