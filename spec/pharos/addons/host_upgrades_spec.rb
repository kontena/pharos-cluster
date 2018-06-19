require 'pharos/addon'
require "./addons/host-upgrades/addon"

describe Pharos::Addons::HostUpgrades do
  let(:cluster_config) { Pharos::Config.load(
    hosts: [ {role: 'worker'} ],
  ) }
  let(:config) { { } }
  let(:cpu_arch) { double(:cpu_arch ) }
  let(:master) { double(:host, address: '192.0.2.1') }

  subject do
    described_class.new({enabled: true}.merge(config), enabled: true, master: master, cpu_arch: cpu_arch, cluster_config: cluster_config)
  end

  describe "#validate" do
    it "fails with missing schedule" do
      result = described_class.validate({enabled: true})

      expect(result).to_not be_success
      expect(result.errors.dig(:schedule)).to eq ["is missing"]
    end

    describe 'schedule' do
      it "fails with empty schedule" do
        result = described_class.validate({enabled: true, schedule: ''})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to eq ["must be filled"]
      end

      it "fails with invalid schedule" do
        result = described_class.validate({enabled: true, schedule: '3'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "fails with short cron schedule" do
        result = described_class.validate({enabled: true, schedule: '0 * * *'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "fails with long cron schedule" do
        result = described_class.validate({enabled: true, schedule: '0 0 0 * * *'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "succeeds with valid @ schedule" do
        result = described_class.validate({enabled: true, schedule: '@daily'})

        expect(result).to be_success, result.errors.inspect
      end

      it "succeeds with valid schedule" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *'})

        expect(result).to be_success, result.errors.inspect
      end

      it "succeeds with range/interval schedule" do
        result = described_class.validate({enabled: true, schedule: '0 3-8/2 * * *'})

        expect(result).to be_success, result.errors.inspect
      end

      it "succeeds with weekday schedule" do
        result = described_class.validate({enabled: true, schedule: '0 3 * * MON,WED,FRI'})

        expect(result).to be_success, result.errors.inspect
      end
    end

    describe 'duration' do
      it "fails with invalid duration" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '1'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule_window)).to match [/is not a valid duration/]
      end

      it "succeeds with a zero duration" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '0s'})

        expect(result).to be_success, result.errors.inspect
      end

      it "succeeds with a simple duration" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '1h'})

        expect(result).to be_success, result.errors.inspect
      end

      it "succeeds with a complex duration" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '1h30m'})

        expect(result).to be_success, result.errors.inspect
      end
    end
  end
end
