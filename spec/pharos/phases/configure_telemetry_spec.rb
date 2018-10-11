require 'pharos/phases/configure_telemetry'
require 'fileutils'

describe Pharos::Phases::ConfigureTelemetry do
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  let(:host) { instance_double(Pharos::Configuration::Host) }
  subject { described_class.new(host, config: instance_double(Pharos::Config)) }
  before do
    allow(host).to receive(:ssh).and_return(ssh)
  end

  describe '#customer_token', fakefs: true do
    it 'returns empty string if not found' do
      FakeFS do
        expect(subject.customer_token).to eq('')
      end
    end

    it 'returns token if found' do
      FakeFS do
        ::FileUtils.mkdir_p(Dir.home)
        ::File.open(File.join(Dir.home, '.chpharosrc'), 'w') do |f|
          f.write('CHPHAROS_TOKEN="asdasd"')
        end
        expect(subject.customer_token).to eq('asdasd')
      end
    end
  end
end
