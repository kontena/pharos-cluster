# frozen_string_literal: true

Pharos.addon 'kontena-backup' do
  using Pharos::CoreExt::DeepTransformKeys

  ark_version = '0.9.11'

  version "#{ark_version}+kontena.1"
  license 'Kontena License'

  config_schema {
    required(:cloud_credentials).filled(:str?)
    optional(:aws).schema do
      required(:region).filled(:str?)
      required(:bucket).filled(:str?)
      optional(:s3_force_path_style).filled(:str?)
      optional(:s3_url).filled(:str?)
    end
    optional(:gcp).schema do
      required(:bucket).filled(:str?)
    end
  }

  def validate
    super

    raise Pharos::InvalidAddonError, "cannot read given cloud credentials file" unless File.readable?(config.cloud_credentials)

    provider_count = count_providers
    raise Pharos::InvalidAddonError, "at least one provider needs to be configured" if provider_count.zero?
    raise Pharos::InvalidAddonError, "only one provider can be configured" if provider_count > 1
  end

  def count_providers
    count = 0

    count += 1 if config.aws
    count += 1 if config.gcp

    count
  end

  install {
    # Encode secret properly for erb templating
    config.cloud_credentials = Base64.strict_encode64(File.read(config.cloud_credentials))

    # Add cloud specific configs
    if config.aws
      ark_config = aws_config
    elsif config.gcp
      ark_config = gcp_config
    end

    apply_resources(
      ark_config: ark_config.deep_stringify_keys,
      ark_version: ark_version
    )
  }

  def aws_config
    ark_config = {
      apiVersion: "ark.heptio.com/v1",
      kind: "Config",
      metadata: {
        namespace: "kontena-backup",
        name: "default"
      },
      backupStorageProvider: {
        name: "aws",
        bucket: config.aws.bucket,
        resticLocation: "#{config.aws.bucket}-restic",
        config: {
          region: config.aws.region
        }
      }
    }

    ark_config[:backupStorageProvider][:config][:s3ForcePathStyle] = config.aws.s3_force_path_style if config.aws.s3_force_path_style
    ark_config[:backupStorageProvider][:config][:s3Url] = config.aws.s3_url if config.aws.s3_url

    ark_config
  end

  def gcp_config
    ark_config = {
      apiVersion: "ark.heptio.com/v1",
      kind: "Config",
      metadata: {
        namespace: "kontena-backup",
        name: "default"
      },
      backupStorageProvider: {
        name: "gcp",
        objectStorage: {
          bucket: config.gcp.bucket,
          resticLocation: "#{config.gcp.bucket}-restic"
        }
      }
    }

    ark_config
  end
end
