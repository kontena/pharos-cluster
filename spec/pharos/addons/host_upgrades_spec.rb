require 'pharos/addon'
require "./addons/host-upgrades/addon"

describe Pharos::Addons::HostUpgrades do
  let(:cluster_config) { Pharos::Config.load(
    hosts: [ {role: 'master', address: '192.0.2.1'} ],
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
      it "rejects empty schedule" do
        result = described_class.validate({enabled: true, schedule: ''})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to eq ["must be filled"]
      end

      it "rejects invalid schedule" do
        result = described_class.validate({enabled: true, schedule: '3'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "rejects short cron schedule" do
        result = described_class.validate({enabled: true, schedule: '0 * * *'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "rejects long cron schedule" do
        result = described_class.validate({enabled: true, schedule: '0 0 0 * * *'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end

      it "accepts valid @ schedule" do
        result = described_class.validate({enabled: true, schedule: '@daily'})

        expect(result).to be_success, result.errors.inspect
      end

      it "accepts valid schedule" do
        result = described_class.validate({enabled: true, schedule: '0 0 * * *'})

        expect(result).to be_success, result.errors.inspect
      end

      it "accepts range/interval schedule" do
        result = described_class.validate({enabled: true, schedule: '0 3-8/2 * * *'})

        expect(result).to be_success, result.errors.inspect
      end

      it "accepts weekday schedule" do
        result = described_class.validate({enabled: true, schedule: '0 3 * * MON,WED,FRI'})

        expect(result).to be_success, result.errors.inspect
      end
    end
  end

  describe '#schedule_window' do
    context "by default" do
      it "normalizes to zero" do
        expect(subject.schedule_window).to eq '0'
      end
    end

    context "with a simple duration" do
      let(:config) { { schedule_window: "1 day" } }

      it "normalizes to seconds" do
        expect(subject.schedule_window).to eq '86400s'
      end
    end

    context "with a simple duration" do
      let(:config) { { schedule_window: "1h30m" } }

      it "normalizes to seconds" do
        expect(subject.schedule_window).to eq '5400s'
      end
    end

    it "handles a zero duration" do
      result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '0s'})

      expect(result).to be_success, result.errors.inspect
    end

    it "handles a simple duration" do
      result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '1h'})

      expect(result).to be_success, result.errors.inspect
    end

    it "handles a complex duration" do
      result = described_class.validate({enabled: true, schedule: '0 0 * * *', schedule_window: '1h30m'})

      expect(result).to be_success, result.errors.inspect
    end
  end
end
