require 'pharos/addon_manager'
Pharos::AddonManager.load_addon "./non-oss/pharos_pro/addons/kontena-backup/addon.rb"

describe Pharos::AddonManager.addons['kontena-backup'] do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { {} }
  let(:kube_client) { instance_double(K8s::Client) }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject { described_class.new(config, enabled: true, cpu_arch: cpu_arch, cluster_config: cluster_config, cluster_context: { 'kube_client' => kube_client }) }

  describe '#validate' do

    context 'cloud credentials' do
      let(:config) {
        {
          cloud_credentials: '/foo/credentials'
        }
      }

      it 'raises if file not readable' do
        expect(File).to receive(:readable?).with('/foo/credentials').and_return(false)

        expect { subject.validate }.to raise_error Pharos::InvalidAddonError
      end
    end

    context 'with no providers' do
      let(:config) {
        {
          cloud_credentials: '/foo/credentials'
        }
      }

      before(:each) do
        expect(File).to receive(:readable?).with('/foo/credentials').and_return(true)
      end

      it 'raises if no providers' do
        expect { subject.validate }.to raise_error Pharos::InvalidAddonError, "at least one provider needs to be configured"
      end
    end

    context 'with many providers' do
      let(:config) {
        {
          cloud_credentials: '/foo/credentials',
          aws: {},
          gcp: {}
        }
      }

      before(:each) do
        expect(File).to receive(:readable?).with('/foo/credentials').and_return(true)
      end

      it 'raises if no providers' do
        expect { subject.validate }.to raise_error Pharos::InvalidAddonError, "only one provider can be configured"
      end
    end
  end

  describe '#aws_config' do
    context 'with aws config' do
      let(:config) {
        {
          aws: {
            region: "eu-west-1",
            bucket: "pharos-backups"
          }
        }
      }

      it 'applies stack with given values' do
        config = subject.aws_config.to_hash

        expect(config.dig(:backupStorageProvider, :bucket)).to eq('pharos-backups')
        expect(config.dig(:backupStorageProvider, :config, :region)).to eq('eu-west-1')
        expect(config.dig(:backupStorageProvider, :config, :s3Url)).to be_nil
        expect(config.dig(:backupStorageProvider, :config, :s3ForcePathStyle)).to be_nil
      end
    end

    context 'with aws optional config' do
      let(:config) {
        {
          aws: {
            region: "eu-west-1",
            bucket: "pharos-backups",
            s3_url: "http://minio.heptio-ark.svc:9000",
            s3_force_path_style: "true"
          }
        }
      }

      it 'applies stack with given values' do
        config = subject.aws_config.to_hash

        expect(config.dig(:backupStorageProvider, :bucket)).to eq('pharos-backups')
        expect(config.dig(:backupStorageProvider, :config, :region)).to eq('eu-west-1')
        expect(config.dig(:backupStorageProvider, :config, :s3Url)).to eq "http://minio.heptio-ark.svc:9000"
        expect(config.dig(:backupStorageProvider, :config, :s3ForcePathStyle)).to eq "true"
      end
    end

  end

  describe '#gcp_config' do
    context 'with aws config' do
      let(:config) {
        {
          gcp: {
            bucket: "pharos-backups"
          }
        }
      }

      it 'applies stack with given values' do
        config = subject.gcp_config.to_hash

        expect(config.dig(:backupStorageProvider, :objectStorage, :bucket)).to eq('pharos-backups')
        expect(config.dig(:backupStorageProvider, :objectStorage, :resticLocation)).to eq('pharos-backups-restic')
        expect(config.dig(:backupStorageProvider, :name)).to eq('gcp')

      end
    end
  end

  describe "#count_providers" do
    context "no providers" do
      let(:config) {
        {
        }
      }

      it 'returns 0' do
        expect(subject.count_providers).to eq 0
      end
    end

    context "aws provider" do
      let(:config) {
        {
          aws: {}
        }
      }

      it 'returns 1' do
        expect(subject.count_providers).to eq 1
      end
    end

    context "aws & gcp provider" do
      let(:config) {
        {
          aws: {},
          gcp: {}
        }
      }

      it 'returns 2' do
        expect(subject.count_providers).to eq 2
      end
    end
  end
end
