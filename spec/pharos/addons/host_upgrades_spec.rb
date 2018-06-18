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

    it "fails with empty schedule" do
      result = described_class.validate({enabled: true, schedule: ''})

      expect(result).to_not be_success
      expect(result.errors.dig(:schedule)).to eq ["must be filled"]
    end

    it "fails with invalid schedule" do
      result = described_class.validate({enabled: true, schedule: '3'})

      expect(result).to_not be_success, result.errors
      #expect(result.errors).to eq {}
    end

    it "fails with invalid cron schedule" do
      result = described_class.validate({enabled: true, schedule: '0 0 * * *'})

      expect(result).to_not be_success, result.errors
      #expect(result.errors).to eq {}
    end

    it "succeeds with valid @ schedule" do
      result = described_class.validate({enabled: true, schedule: '@daily'})

      expect(result).to be_success, result.errors.inspect
    end

    it "succeeds with valid schedule" do
      result = described_class.validate({enabled: true, schedule: '0 0 0 * * *'})

      expect(result).to be_success, result.errors.inspect
    end

    it "succeeds with range/interval schedule" do
      result = described_class.validate({enabled: true, schedule: '0 0 3-8/2 * * *'})

      expect(result).to be_success, result.errors.inspect
    end

    it "succeeds with weekday schedule" do
      result = described_class.validate({enabled: true, schedule: '0 0 3 * * MON,WED,FRI'})

      expect(result).to be_success, result.errors.inspect
    end
  end
end
