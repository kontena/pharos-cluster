require 'pharos/config'

describe Pharos::Configuration::Host do
  let(:subject) do
    described_class.new(
      address: '192.0.2.1'
    )
  end

  describe '#short_hostname' do
    let(:hostname) { nil }

    before do
      subject.hostname = hostname if hostname
    end

    it 'returns nil if no hostname is set' do
      expect(subject.short_hostname).to eq nil
    end

    context 'with a short hostname' do
      let(:hostname) { 'test' }

      it 'returns the hostname as-is' do
        expect(subject.short_hostname).to eq 'test'
      end
    end

    context 'with an fqdn hostname' do
      let(:hostname) { 'test.example.com' }

      it 'returns the short hostname' do
        expect(subject.short_hostname).to eq 'test'
      end
    end
  end
end
