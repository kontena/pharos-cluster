require 'pharos/phases/validate_hostname_uniqueness'

describe Pharos::Phases::ValidateHostnameUniqueness do
  let(:config) do
    Pharos::Config.new(
      hosts: (1..5).map do |i|
        Pharos::Configuration::Host.new(address: "127.0.0.#{i}").tap { |h| h.hostname = "host-#{i}" }
      end
    )
  end

  subject { described_class.new(config.hosts[0], config: config) }

  context 'when hostnames are unique' do
    it 'does not raise errors' do
      expect{subject.call}.not_to raise_error
    end
  end

  context 'when hostnames contain duplicates' do
    before do
      [1, 4, 6].each do |i|
        config.hosts << Pharos::Configuration::Host.new(address: "127.0.0.#{i+10}").tap { |h| h.hostname = "host-#{i}" }
      end
    end

    it 'raises' do
      expect{subject.call}.to raise_error(Pharos::InvalidHostError, /Non-unique hostnames host-1, host-4/)
    end
  end
end
