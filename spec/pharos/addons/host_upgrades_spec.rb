require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./addons/host-upgrades/addon.rb"

describe Pharos::AddonManager.addons['host-upgrades'] do
  let(:cluster_config) { Pharos::Config.load(
    hosts: [ {role: 'master', address: '192.0.2.1'} ],
  ) }
  let(:config) { { } }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject do
    described_class.new({enabled: true}.merge(config), enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client })
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
        result = described_class.validate({enabled: true, schedule: '30 0 0 * * *'})

        expect(result).to_not be_success
        expect(result.errors.dig(:schedule)).to match [/is not a valid crontab/]
      end
    end
  end

  describe '#schedule' do
    let(:config) { { schedule: schedule } }

    context "with a @ schedule" do
      let(:schedule) { '@daily' }

      it "normalizes it" do
        expect(subject.schedule).to eq '0 0 * * *'
      end
    end

    context "with a seconds schedule" do
      let(:schedule) { '0 30 3 * * *' }

      it "normalizes it" do
        expect(subject.schedule).to eq '30 3 * * *'
      end
    end

    context "with a simple schedule" do
      let(:schedule) { '0 0 * * *' }

      it "passes it through" do
        expect(subject.schedule).to eq schedule
      end
    end

    context "with a range/interval schedule" do
      let(:schedule) { '0 3-8/2 * * *' }

      it "normalizes it" do
        expect(subject.schedule).to eq '0 3,5,7 * * *'
      end
    end

    context "with a weekday schedule" do
      let(:schedule) { '0 3 * * 1,3,5' }

      it "normalizes it" do
        expect(subject.schedule).to eq schedule
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
  end
end
