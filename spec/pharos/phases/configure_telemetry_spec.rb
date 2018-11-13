require 'pharos/phases/configure_telemetry'
require 'fileutils'

describe Pharos::Phases::ConfigureTelemetry do
  subject { described_class.new(double, config: double) }

  describe '#customer_token' do
    it 'returns empty string if not found' do
      FakeFS do
        expect(subject.customer_token).to eq('')
      end
    end

    it 'returns token if found' do
      FakeFS do
        FileUtils.mkdir_p(Dir.home)
        File.open(File.join(Dir.home, '.chpharosrc'), 'w') do |f|
          f.write('CHPHAROS_TOKEN="asdasd"')
        end
        expect(subject.customer_token).to eq('asdasd')
      end
    end
  end
end
